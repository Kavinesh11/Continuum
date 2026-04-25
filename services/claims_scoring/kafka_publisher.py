import json
import logging
import os

logger = logging.getLogger(__name__)


async def publish_claim_decision(response, worker_id: str) -> None:
    try:
        from aiokafka import AIOKafkaProducer
    except ImportError:
        logger.warning("aiokafka not available — skipping Kafka publish")
        return

    from models import ClaimStatus

    brokers = os.getenv("KAFKA_BROKERS", "localhost:9092")
    event = {
        "claim_id": str(response.claim_id),
        "worker_id": str(worker_id),
        "status": response.status.value.lower(),
        "fraud_score": response.fraud_score,
        "decided_at": response.decided_at.isoformat(),
    }

    producer = AIOKafkaProducer(bootstrap_servers=brokers)
    try:
        await producer.start()
        payload = json.dumps(event).encode()
        key = str(response.claim_id).encode()

        await producer.send_and_wait("claim_decision", value=payload, key=key)
        logger.info("Published claim_decision claim_id=%s", response.claim_id)

        if response.status == ClaimStatus.AUTO_APPROVED:
            payout_event = {
                "claim_id": str(response.claim_id),
                "worker_id": str(worker_id),
                "fraud_score": response.fraud_score,
                "authorized_at": response.decided_at.isoformat(),
            }
            await producer.send_and_wait(
                "payout_authorized",
                value=json.dumps(payout_event).encode(),
                key=key,
            )
            logger.info("Published payout_authorized claim_id=%s", response.claim_id)

        elif response.status == ClaimStatus.FRAUD_QUEUE:
            alert_event = {
                "alert_type": "fraud_queue_routing",
                "claim_id": str(response.claim_id),
                "worker_id": str(worker_id),
                "fraud_score": response.fraud_score,
                "triggered_at": response.decided_at.isoformat(),
            }
            await producer.send_and_wait(
                "fraud_alert",
                value=json.dumps(alert_event).encode(),
                key=key,
            )
            logger.info("Published fraud_alert claim_id=%s", response.claim_id)
    finally:
        await producer.stop()
