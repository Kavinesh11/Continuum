"""
Prometheus metrics definitions for the Oracle Consensus Engine.

Alert rule: oracle_failure_rate > 0.5 for any oracle_name label → page on-call
Prometheus alerting rule (add to prometheus.yml rules):
- alert: OracleHighFailureRate
  expr: oracle_failure_rate > 0.5
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "Oracle failure rate > 50% for {{ $labels.oracle_name }}"
"""
from __future__ import annotations

import os

from prometheus_client import Counter, Gauge, start_http_server

# Total polls per oracle
oracle_polls_total = Counter(
    "oracle_polls_total",
    "Total number of polls per oracle",
    ["oracle_name"],
)

# Failures (abstain + nullified) per oracle, broken down by reason
oracle_failures_total = Counter(
    "oracle_failures_total",
    "Total oracle failures (abstain or nullified votes)",
    ["oracle_name", "reason"],
)

# Rolling failure rate (0.0–1.0) per oracle
oracle_failure_rate = Gauge(
    "oracle_failure_rate",
    "Rolling failure rate per oracle (failures / total polls)",
    ["oracle_name"],
)

# Authorized parametric triggers
oracle_trigger_authorized_total = Counter(
    "oracle_trigger_authorized_total",
    "Total number of authorized parametric triggers",
)

# Denied parametric triggers
oracle_trigger_denied_total = Counter(
    "oracle_trigger_denied_total",
    "Total number of denied parametric triggers",
)

# Benefit of Doubt activations
benefit_of_doubt_applied_total = Counter(
    "benefit_of_doubt_applied_total",
    "Total number of Benefit of Doubt protocol activations",
)


def start_metrics_server(port: int = 8003) -> None:
    """Start the Prometheus HTTP metrics server on the given port."""
    start_http_server(port)
