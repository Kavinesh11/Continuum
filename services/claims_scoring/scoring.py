from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from checks.spatial import SpatialResult
    from checks.frequency import FrequencyResult

SPATIAL_WEIGHT = 0.4
FREQUENCY_WEIGHT = 0.2
ISOLATION_FOREST_WEIGHT = 0.4
AUTO_APPROVE_THRESHOLD = 0.7


@dataclass
class ScoringInputs:
    claim_id: str
    spatial: "SpatialResult"
    frequency: "FrequencyResult"
    isolation_forest_score: float
    flags: list
    spatial_penalty: float
    soak_period_failed: bool
    platform_activity_veto: bool
    coverage_cap: float
    payout_cap: float
    adjacency_factor: float


def compute_score(inputs: ScoringInputs):
    from models import ClaimStatus, ScoreResponse

    adjusted_spatial = max(0.0, min(1.0, inputs.spatial.score - inputs.spatial_penalty))

    fraud_score = max(0.0, min(1.0,
        SPATIAL_WEIGHT * adjusted_spatial
        + FREQUENCY_WEIGHT * inputs.frequency.score
        + ISOLATION_FOREST_WEIGHT * inputs.isolation_forest_score
    ))

    flags = list(inputs.flags)
    if inputs.spatial.zone_mismatch and "ZONE_MISMATCH" not in flags:
        flags.append("ZONE_MISMATCH")

    if inputs.platform_activity_veto:
        status = ClaimStatus.PLATFORM_ACTIVITY_VETO
    elif inputs.frequency.velocity_cap_exceeded or inputs.soak_period_failed:
        status = ClaimStatus.FRAUD_QUEUE
    elif fraud_score >= AUTO_APPROVE_THRESHOLD:
        status = ClaimStatus.AUTO_APPROVED
    else:
        status = ClaimStatus.FRAUD_QUEUE

    estimated_payout = (
        inputs.coverage_cap * inputs.payout_cap * inputs.adjacency_factor
        if status == ClaimStatus.AUTO_APPROVED
        else 0.0
    )

    return ScoreResponse(
        claim_id=inputs.claim_id,
        status=status,
        fraud_score=fraud_score,
        spatial_score=adjusted_spatial,
        frequency_score=inputs.frequency.score,
        isolation_forest_score=inputs.isolation_forest_score,
        flags=flags,
        estimated_payout=estimated_payout,
        decided_at=datetime.now(timezone.utc),
    )
