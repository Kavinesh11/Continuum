from prometheus_client import Counter, Histogram, generate_latest

CLAIMS_AUTO_APPROVED_TOTAL = Counter(
    "claims_auto_approved_total",
    "Total number of auto-approved claims",
)

CLAIMS_FRAUD_QUEUED_TOTAL = Counter(
    "claims_fraud_queued_total",
    "Total number of claims routed to fraud queue",
)

FRAUD_SCORE_HISTOGRAM = Histogram(
    "fraud_score_histogram",
    "Distribution of composite fraud scores",
    buckets=[0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0],
)


def gather_metrics() -> str:
    return generate_latest().decode("utf-8")
