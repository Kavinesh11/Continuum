pub mod checks;
pub mod metrics;
pub mod models;
pub mod population_fraud;
pub mod scoring;

#[cfg(feature = "kafka")]
pub mod kafka_publisher;

// Re-export gps_spoofing at crate level for test access
pub use checks::gps_spoofing;
