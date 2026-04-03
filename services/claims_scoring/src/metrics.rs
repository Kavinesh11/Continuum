use lazy_static::lazy_static;
use prometheus::{
    register_counter, register_histogram, Counter, Encoder, Histogram, HistogramOpts, Opts,
    TextEncoder,
};

lazy_static! {
    pub static ref CLAIMS_AUTO_APPROVED_TOTAL: Counter = register_counter!(
        Opts::new("claims_auto_approved_total", "Total number of auto-approved claims")
    )
    .unwrap();

    pub static ref CLAIMS_FRAUD_QUEUED_TOTAL: Counter = register_counter!(
        Opts::new("claims_fraud_queued_total", "Total number of claims routed to fraud queue")
    )
    .unwrap();

    pub static ref FRAUD_SCORE_HISTOGRAM: Histogram = register_histogram!(
        HistogramOpts::new("fraud_score_histogram", "Distribution of composite fraud scores")
            .buckets(vec![0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0])
    )
    .unwrap();
}

pub fn gather_metrics() -> String {
    let encoder = TextEncoder::new();
    let metric_families = prometheus::gather();
    let mut buffer = Vec::new();
    encoder.encode(&metric_families, &mut buffer).unwrap();
    String::from_utf8(buffer).unwrap()
}
