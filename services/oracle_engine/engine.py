"""
Oracle Consensus Engine — voting logic, staleness checks, and trigger evaluation.
"""
from __future__ import annotations

import asyncio
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Literal

import structlog

from .oracles import ALL_ORACLE_CLIENTS, OracleClient, OracleVote

try:
    from .metrics import (
        benefit_of_doubt_applied_total,
        oracle_failure_rate,
        oracle_failures_total,
        oracle_polls_total,
        oracle_trigger_authorized_total,
        oracle_trigger_denied_total,
    )
    _METRICS_AVAILABLE = True
except ImportError:
    _METRICS_AVAILABLE = False

logger = structlog.get_logger(__name__)

STALENESS_WINDOW_MINUTES = 15
AFFIRMATIVE_THRESHOLD = 3  # 3-of-4 required


@dataclass
class VoteResult:
    authorized: bool
    affirmative_count: int
    abstain_count: int
    deny_count: int
    nullified_count: int
    payout_cap: float  # 1.0 = full, 0.5 = benefit-of-doubt cap
    votes: list[OracleVote]
    benefit_of_doubt: bool = False


class OracleConsensusEngine:
    def __init__(
        self,
        clients: list[OracleClient] | None = None,
        staleness_minutes: int = STALENESS_WINDOW_MINUTES,
    ) -> None:
        self._clients = clients if clients is not None else ALL_ORACLE_CLIENTS
        self._staleness_minutes = staleness_minutes
        # Track cumulative polls/failures per oracle for failure rate gauge
        self._poll_counts: dict[str, int] = {}
        self._failure_counts: dict[str, int] = {}

    async def poll_all_oracles(self, zone_id: str, event_type: str) -> list[OracleVote]:
        """Poll all 4 oracles concurrently."""
        tasks = [client.poll(zone_id, event_type) for client in self._clients]
        votes: list[OracleVote] = await asyncio.gather(*tasks)
        votes = list(votes)

        if _METRICS_AVAILABLE:
            for vote in votes:
                name = vote.oracle_name
                oracle_polls_total.labels(oracle_name=name).inc()
                self._poll_counts[name] = self._poll_counts.get(name, 0) + 1

                if vote.vote in ("abstain", "nullified"):
                    oracle_failures_total.labels(oracle_name=name, reason=vote.vote).inc()
                    self._failure_counts[name] = self._failure_counts.get(name, 0) + 1

                total = self._poll_counts[name]
                failures = self._failure_counts.get(name, 0)
                oracle_failure_rate.labels(oracle_name=name).set(failures / total)

        return votes

    def apply_staleness_rule(self, votes: list[OracleVote]) -> list[OracleVote]:
        """
        Convert any vote whose data_timestamp is older than STALENESS_WINDOW_MINUTES
        to an abstention. Nullified votes are left unchanged (already non-affirmative).
        """
        now = datetime.now(timezone.utc)
        cutoff = now - timedelta(minutes=self._staleness_minutes)
        updated: list[OracleVote] = []

        for vote in votes:
            if vote.vote in ("abstain", "nullified"):
                updated.append(vote)
                continue

            if vote.data_timestamp is None:
                # No timestamp → treat as stale
                logger.info(
                    "oracle_vote_stale_no_timestamp",
                    oracle=vote.oracle_name,
                    original_vote=vote.vote,
                )
                updated.append(
                    OracleVote(
                        oracle_name=vote.oracle_name,
                        vote="abstain",
                        data_timestamp=vote.data_timestamp,
                        polled_at=vote.polled_at,
                        tls_valid=vote.tls_valid,
                        raw_payload=vote.raw_payload,
                    )
                )
                continue

            # Ensure timezone-aware comparison
            data_ts = vote.data_timestamp
            if data_ts.tzinfo is None:
                data_ts = data_ts.replace(tzinfo=timezone.utc)

            if data_ts < cutoff:
                logger.info(
                    "oracle_vote_converted_stale",
                    oracle=vote.oracle_name,
                    data_timestamp=data_ts.isoformat(),
                    cutoff=cutoff.isoformat(),
                    original_vote=vote.vote,
                )
                updated.append(
                    OracleVote(
                        oracle_name=vote.oracle_name,
                        vote="abstain",
                        data_timestamp=vote.data_timestamp,
                        polled_at=vote.polled_at,
                        tls_valid=vote.tls_valid,
                        raw_payload=vote.raw_payload,
                    )
                )
            else:
                updated.append(vote)

        return updated

    def check_benefit_of_doubt(self, votes: list[OracleVote]) -> bool:
        """
        Benefit of Doubt: ≥2 oracles offline (abstain/nullified) AND
        confirmed disaster (≥1 affirm) AND ≥1 confirming oracle.
        Returns True if the protocol should apply.
        """
        offline = sum(1 for v in votes if v.vote in ("abstain", "nullified"))
        confirming = sum(1 for v in votes if v.vote == "affirm")
        return offline >= 2 and confirming >= 1

    def evaluate_votes(self, votes: list[OracleVote]) -> VoteResult:
        """
        Count votes and return a VoteResult with trigger decision.
        Logs TLS nullifications.
        """
        affirmative = sum(1 for v in votes if v.vote == "affirm")
        deny = sum(1 for v in votes if v.vote == "deny")
        abstain = sum(1 for v in votes if v.vote == "abstain")
        nullified = sum(1 for v in votes if v.vote == "nullified")

        # Log any TLS nullifications
        for v in votes:
            if v.vote == "nullified":
                logger.warning(
                    "oracle_tls_nullification",
                    oracle=v.oracle_name,
                    polled_at=v.polled_at.isoformat(),
                )

        authorized = affirmative >= AFFIRMATIVE_THRESHOLD
        benefit_of_doubt = False
        payout_cap = 1.0

        if not authorized:
            benefit_of_doubt = self.check_benefit_of_doubt(votes)
            if benefit_of_doubt:
                authorized = True
                payout_cap = 0.5
                logger.info(
                    "benefit_of_doubt_applied",
                    affirmative=affirmative,
                    offline=abstain + nullified,
                )

        if not authorized:
            logger.info(
                "parametric_trigger_not_authorized",
                affirmative=affirmative,
                deny=deny,
                abstain=abstain,
                nullified=nullified,
            )

        if _METRICS_AVAILABLE:
            if authorized:
                oracle_trigger_authorized_total.inc()
            else:
                oracle_trigger_denied_total.inc()
            if benefit_of_doubt:
                benefit_of_doubt_applied_total.inc()

        return VoteResult(
            authorized=authorized,
            affirmative_count=affirmative,
            abstain_count=abstain,
            deny_count=deny,
            nullified_count=nullified,
            payout_cap=payout_cap,
            votes=votes,
            benefit_of_doubt=benefit_of_doubt,
        )

    async def run_cycle(self, zone_id: str, event_type: str) -> VoteResult:
        """Full poll → staleness → evaluate pipeline for one cycle."""
        raw_votes = await self.poll_all_oracles(zone_id, event_type)
        fresh_votes = self.apply_staleness_rule(raw_votes)
        result = self.evaluate_votes(fresh_votes)
        return result
