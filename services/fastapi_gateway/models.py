# Feature: continuum-ml-pipelines
from datetime import datetime
from typing import Literal
from pydantic import BaseModel


class ActivityRecord(BaseModel):
    date: str  # ISO date string e.g. "2024-01-15"
    orders: int


class OnboardingPayload(BaseModel):
    worker_id: str
    zone_id: str
    platform: Literal["swiggy", "zomato"]
    tier: Literal["silver", "gold", "platinum"]
    gps_coordinates: tuple[float, float]  # (lat, lon)
    activity_history: list[ActivityRecord]


class ClaimPayload(BaseModel):
    claim_id: str
    worker_id: str
    event_type: str
    event_timestamp: datetime
    gps_coordinates: tuple[float, float]
    zone_id: str
    device_attestation_token: str
