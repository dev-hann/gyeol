use async_trait::async_trait;
use crate::providers::{LlmProvider, LlmError};
use serde_json::json;

pub struct OllamaProvider {
    base_url: String,
    model: String,
    temperature: f64,
    max_tokens: u32,
    client: reqwest::Client,
}

impl OllamaProvider {
    pub fn new(base_url: &str, model: &str, temperature: f64, max_tokens: u32) -> Self {
        Self {
            base_url: base_url.trim_end_matches('/').to_string(),
            model: model.to_string(),
            temperature,
            max_tokens,
            client: reqwest::Client::new(),
        }
    }
}

#[async_trait]
impl LlmProvider for OllamaProvider {
    async fn generate(&self, prompt: &str) -> Result<String, LlmError> {
        self.generate_with_system("You are a helpful AI assistant.", prompt).await
    }

    async fn generate_with_system(&self, system: &str, user: &str) -> Result<String, LlmError> {
        let body = json!({
            "model": self.model,
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": user}
            ],
            "temperature": self.temperature,
            "options": {
                "num_predict": self.max_tokens,
            },
            "stream": false,
        });

        let url = format!("{}/api/chat", self.base_url);
        let response = self.client
            .post(&url)
            .header("Content-Type", "application/json")
            .json(&body)
            .send()
            .await
            .map_err(|e| LlmError::NetworkError(e.to_string()))?;

        if !response.status().is_success() {
            let status = response.status();
            let text = response.text().await.unwrap_or_default();
            return Err(LlmError::ApiError(format!("{}: {}", status, text)));
        }

        let data: serde_json::Value = response
            .json()
            .await
            .map_err(|e| LlmError::ApiError(e.to_string()))?;

        data["message"]["content"]
            .as_str()
            .map(|s| s.to_string())
            .ok_or_else(|| LlmError::ApiError("No content in response".to_string()))
    }

    fn provider_name(&self) -> &str {
        "ollama"
    }
}
