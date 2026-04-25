from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel


class GpsPoint(BaseModel):
    lat: float
    lon: float
    ts: datetime


class ScoreRequest(BaseModel):
    claim_id: str
    worker_id: str
    policy_id: Optional[str] = None
    event_type: str
    event_timestamp: datetime
    gps_coordinates: list[float]  # [lat, lon]
    zone_id: str
    device_attestation_token: str
    cell_id_coordinates: Optional[list[float]] = None
    gps_history: Optional[list[GpsPoint]] = None
    claim_feature_vector: Optional[list[float]] = None
    device_id: Optional[str] = None
    coverage_cap: Optional[float] = None
    payout_cap: Optional[float] = None
    adjacency_factor: Optional[float] = None


class ClaimStatus(str, Enum):
    AUTO_APPROVED = "AUTO_APPROVED"
    FRAUD_QUEUE = "FRAUD_QUEUE"
    DEVICE_NOT_ATTESTED = "DEVICE_NOT_ATTESTED"
    PLATFORM_ACTIVITY_VETO = "PLATFORM_ACTIVITY_VETO"


class ScoreResponse(BaseModel):
    claim_id: str
    status: ClaimStatus
    fraud_score: float
    spatial_score: float
    frequency_score: float
    isolation_forest_score: float
    flags: list[str]
    estimated_payout: float
    decided_at: datetime


class ClaimDecisionEvent(BaseModel):
    claim_id: str
    worker_id: str
    status: str
    fraud_score: float
    decided_at: datetime
