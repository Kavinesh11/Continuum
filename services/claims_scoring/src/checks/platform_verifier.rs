use async_trait::async_trait;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OrderCheckResult {
    pub orders_found: bool,
    pub order_count: u32,
    pub provider: String,
}

#[async_trait]
pub trait PlatformOrderVerifier: Send + Sync {
    async fn check_orders(
        &self,
        worker_id: &str,
        platform: &str,
        window_start: &str,
        window_end: &str,
    ) -> Result<OrderCheckResult, Box<dyn std::error::Error + Send + Sync>>;
}

/// Mock verifier for dev/CI — always returns no orders found.
pub struct MockVerifier;

#[async_trait]
impl PlatformOrderVerifier for MockVerifier {
    async fn check_orders(
        &self,
        _worker_id: &str,
        _platform: &str,
        _window_start: &str,
        _window_end: &str,
    ) -> Result<OrderCheckResult, Box<dyn std::error::Error + Send + Sync>> {
        Ok(OrderCheckResult {
            orders_found: false,
            order_count: 0,
            provider: "mock".to_string(),
        })
    }
}

/// Swiggy API verifier (prod shell — requires SWIGGY_API_URL + SWIGGY_API_KEY).
pub struct SwiggyVerifier {
    base_url: String,
    api_key: String,
}

impl SwiggyVerifier {
    pub fn new() -> Result<Self, String> {
        let base_url = std::env::var("SWIGGY_API_URL")
            .map_err(|_| "SWIGGY_API_URL not set".to_string())?;
        let api_key = std::env::var("SWIGGY_API_KEY")
            .map_err(|_| "SWIGGY_API_KEY not set".to_string())?;
        Ok(Self { base_url, api_key })
    }
}

#[async_trait]
impl PlatformOrderVerifier for SwiggyVerifier {
    async fn check_orders(
        &self,
        worker_id: &str,
        _platform: &str,
        window_start: &str,
        window_end: &str,
    ) -> Result<OrderCheckResult, Box<dyn std::error::Error + Send + Sync>> {
        let client = reqwest::Client::new();
        let resp = client
            .get(&format!("{}/partner/orders", self.base_url))
            .header("Authorization", format!("Bearer {}", self.api_key))
            .query(&[
                ("partner_id", worker_id),
                ("from", window_start),
                ("to", window_end),
            ])
            .timeout(std::time::Duration::from_secs(15))
            .send()
            .await?;

        let data: serde_json::Value = resp.json().await?;
        let count = data["orders"].as_array().map(|a| a.len() as u32).unwrap_or(0);

        Ok(OrderCheckResult {
            orders_found: count > 0,
            order_count: count,
            provider: "swiggy".to_string(),
        })
    }
}

/// Zomato API verifier (prod shell).
pub struct ZomatoVerifier {
    base_url: String,
    api_key: String,
}

impl ZomatoVerifier {
    pub fn new() -> Result<Self, String> {
        let base_url = std::env::var("ZOMATO_API_URL")
            .map_err(|_| "ZOMATO_API_URL not set".to_string())?;
        let api_key = std::env::var("ZOMATO_API_KEY")
            .map_err(|_| "ZOMATO_API_KEY not set".to_string())?;
        Ok(Self { base_url, api_key })
    }
}

#[async_trait]
impl PlatformOrderVerifier for ZomatoVerifier {
    async fn check_orders(
        &self,
        worker_id: &str,
        _platform: &str,
        window_start: &str,
        window_end: &str,
    ) -> Result<OrderCheckResult, Box<dyn std::error::Error + Send + Sync>> {
        let client = reqwest::Client::new();
        let resp = client
            .get(&format!("{}/delivery-partner/orders", self.base_url))
            .header("Authorization", format!("Bearer {}", self.api_key))
            .query(&[
                ("partner_id", worker_id),
                ("from", window_start),
                ("to", window_end),
            ])
            .timeout(std::time::Duration::from_secs(15))
            .send()
            .await?;

        let data: serde_json::Value = resp.json().await?;
        let count = data["orders"].as_array().map(|a| a.len() as u32).unwrap_or(0);

        Ok(OrderCheckResult {
            orders_found: count > 0,
            order_count: count,
            provider: "zomato".to_string(),
        })
    }
}

pub fn create_verifier(platform: &str) -> Box<dyn PlatformOrderVerifier> {
    let provider = std::env::var("PLATFORM_VERIFIER_PROVIDER")
        .unwrap_or_else(|_| "mock".to_string());

    match provider.as_str() {
        "prod" => match platform {
            "swiggy" => match SwiggyVerifier::new() {
                Ok(v) => Box::new(v),
                Err(_) => Box::new(MockVerifier),
            },
            "zomato" => match ZomatoVerifier::new() {
                Ok(v) => Box::new(v),
                Err(_) => Box::new(MockVerifier),
            },
            _ => Box::new(MockVerifier),
        },
        _ => Box::new(MockVerifier),
    }
}
