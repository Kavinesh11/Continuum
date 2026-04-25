import asyncio
import logging
import os
import uuid
from contextlib import asynccontextmanager
from datetime import datetime, timezone

import asyncpg
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse, PlainTextResponse

import attestation
import kafka_publisher
import metrics
import population_fraud
from checks import frequency as frequency_checks
from checks import gps_spoofing as gps_spoofing_checks
from checks import isolation_forest as if_checks
from checks import spatial as spatial_checks
from models import ClaimStatus, ScoreRequest, ScoreResponse
from scoring import ScoringInputs, compute_score

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    database_url = os.environ["DATABASE_URL"]
    app.state.db = await asyncpg.create_pool(database_url)
    yield
    await app.state.db.close()


app = FastAPI(title="Claims Scoring Service", lifespan=lifespan)


@app.get("/metrics")
async def metrics_handler():
    return PlainTextResponse(
        content=metrics.gather_metrics(),
        media_type="text/plain; version=0.0.4",
    )


@app.post("/score")
async def score_handler(req: ScoreRequest, request: Request):
    logger.info("Received score request claim_id=%s worker_id=%s", req.claim_id, req.worker_id)
    try:
        response = await process_claim(request.app.state.db, req)
        return response
    except Exception as e:
        logger.exception("Unhandled error in score_handler: %s", e)
        return JSONResponse(
            status_code=500,
            content={"error": "internal_server_error"},
        )


async def process_claim(pool: asyncpg.Pool, req: ScoreRequest) -> ScoreResponse:
    now = lambda: datetime.now(timezone.utc)

    # Step 1: Play Integrity attestation
    try:
        attested = await attestation.verify_attestation(req.device_attestation_token)
    except Exception as e:
        logger.error("Attestation service unreachable claim_id=%s error=%s", req.claim_id, e)
        return ScoreResponse(
            claim_id=req.claim_id,
            status=ClaimStatus.DEVICE_NOT_ATTESTED,
            fraud_score=0.0,
            spatial_score=0.0,
            frequency_score=0.0,
            isolation_forest_score=0.0,
            flags=["ATTESTATION_SERVICE_UNAVAILABLE"],
            estimated_payout=0.0,
            decided_at=now(),
        )

    if not attested:
        logger.info("Device attestation failed — rejecting claim claim_id=%s", req.claim_id)
        return ScoreResponse(
            claim_id=req.claim_id,
            status=ClaimStatus.DEVICE_NOT_ATTESTED,
            fraud_score=0.0,
            spatial_score=0.0,
            frequency_score=0.0,
            isolation_forest_score=0.0,
            flags=[],
            estimated_payout=0.0,
            decided_at=now(),
        )

    # Step 2: GPS spoofing pre-checks
    spoofing_result = await gps_spoofing_checks.run_gps_spoofing_checks(
        pool=pool,
        claim_id=req.claim_id,
        worker_id=req.worker_id,
        gps_coordinates=req.gps_coordinates,
        cell_id_coordinates=req.cell_id_coordinates,
        gps_history=req.gps_history,
        event_timestamp=req.event_timestamp,
        zone_id=req.zone_id,
    )

    flags = spoofing_result.flags
    spatial_penalty = spoofing_result.spatial_penalty
    soak_period_failed = spoofing_result.soak_period_failed
    platform_activity_veto = spoofing_result.platform_activity_veto

    # Step 3: Three parallel checks
    lat, lon = req.gps_coordinates[0], req.gps_coordinates[1]
    feature_vector = req.claim_feature_vector or [0.0] * 6

    spatial_result, frequency_result, if_score = await asyncio.gather(
        spatial_checks.check_spatial(pool, req.zone_id, lat, lon),
        frequency_checks.check_frequency(pool, req.worker_id),
        if_checks.check_isolation_forest(feature_vector),
    )

    # Step 4: Composite score
    coverage_cap = req.coverage_cap or 0.0
    payout_cap = req.payout_cap or 1.0
    if req.adjacency_factor is not None:
        adjacency_factor = req.adjacency_factor
    else:
        adjacency_factor = 0.5 if spatial_result.zone_mismatch else 1.0

    inputs = ScoringInputs(
        claim_id=req.claim_id,
        spatial=spatial_result,
        frequency=frequency_result,
        isolation_forest_score=if_score,
        flags=flags,
        spatial_penalty=spatial_penalty,
        soak_period_failed=soak_period_failed,
        platform_activity_veto=platform_activity_veto,
        coverage_cap=coverage_cap,
        payout_cap=payout_cap,
        adjacency_factor=adjacency_factor,
    )

    response = compute_score(inputs)

    # Step 5: Population-level fraud checks
    policy_id = req.policy_id or str(uuid.uuid4())
    pop_result = await population_fraud.check_population_fraud(
        pool=pool,
        zone_id=req.zone_id,
        policy_id=policy_id,
        worker_id=req.worker_id,
        device_id=req.device_id or "",
        submitted_at=req.event_timestamp,
    )

    if pop_result.convergence_freeze:
        response.status = ClaimStatus.FRAUD_QUEUE
        if "CONVERGENCE_FREEZE" not in response.flags:
            response.flags.append("CONVERGENCE_FREEZE")
        logger.info(
            "Convergence Freeze claim_id=%s zone_id=%s count=%d",
            req.claim_id, req.zone_id, pop_result.claim_count_5min,
        )

    if pop_result.device_cluster_flagged:
        if "DEVICE_CLUSTER" not in response.flags:
            response.flags.append("DEVICE_CLUSTER")
        logger.info(
            "Device proximity cluster claim_id=%s cluster_size=%d",
            req.claim_id, pop_result.cluster_size,
        )

    # Step 6: DB fallback for estimated_payout
    if response.status == ClaimStatus.AUTO_APPROVED and response.estimated_payout == 0.0:
        if req.policy_id:
            try:
                cap_str = await pool.fetchval(
                    "SELECT coverage_cap::TEXT FROM policies WHERE policy_id = $1",
                    req.policy_id,
                )
                if cap_str is not None:
                    db_cap = float(cap_str)
                    response.estimated_payout = db_cap * payout_cap * adjacency_factor
            except Exception as e:
                logger.error("DB fallback for coverage_cap failed: %s", e)

    # Step 7: Emit Prometheus metrics
    metrics.FRAUD_SCORE_HISTOGRAM.observe(response.fraud_score)
    if response.status == ClaimStatus.AUTO_APPROVED:
        metrics.CLAIMS_AUTO_APPROVED_TOTAL.inc()
    elif response.status == ClaimStatus.FRAUD_QUEUE:
        metrics.CLAIMS_FRAUD_QUEUED_TOTAL.inc()

    # Step 8: Kafka event publishing (best-effort)
    try:
        await kafka_publisher.publish_claim_decision(response, req.worker_id)
    except Exception as e:
        logger.error(
            "Failed to publish claim_decision to Kafka claim_id=%s error=%s", req.claim_id, e,
        )

    logger.info(
        "Claim scoring complete claim_id=%s status=%s fraud_score=%.3f",
        req.claim_id, response.status, response.fraud_score,
    )

    return response


if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", "8080"))
    uvicorn.run("main:app", host="0.0.0.0", port=port)
