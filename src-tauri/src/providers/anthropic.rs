use async_trait::async_trait;
use crate::providers::{LlmProvider, LlmError};
use serde_json::json;

pub struct AnthropicProvider {
    api_key: String,
    model: String,
    temperature: f64,
    max_tokens: u32,
    client: reqwest::Client,
}

impl AnthropicProvider {
    pub fn new(api_key: &str, model: &str, temperature: f64, max_tokens: u32) -> Self {
        Self {
            api_key: api_key.to_string(),
            model: model.to_string(),
            temperature,
            max_tokens,
            client: reqwest::Client::new(),
        }
    }
}

#[async_trait]
impl LlmProvider for AnthropicProvider {
    async fn generate(&self, prompt: &str) -> Result<String, LlmError> {
        self.generate_with_system("You are a helpful AI assistant.", prompt).await
    }

    async fn generate_with_system(&self, system: &str, user: &str) -> Result<String, LlmError> {
        if self.api_key.is_empty() {
            return Err(LlmError::Config("Anthropic API key not set".to_string()));
        }

        let body = json!({
            "model": self.model,
            "system": system,
            "messages": [
                {"role": "user", "content": user}
            ],
            "temperature": self.temperature,
            "max_tokens": self.max_tokens,
        });

        let response = self.client
            .post("https://api.anthropic.com/v1/messages")
            .header("x-api-key", &self.api_key)
            .header("anthropic-version", "2023-06-01")
            .header("Content-Type", "application/json")
            .json(&body)
            .send()
            .await
            .map_err(|e| LlmError::Network(e.to_string()))?;

        if !response.status().is_success() {
            let status = response.status();
            let text = response.text().await.unwrap_or_default();
            return Err(LlmError::Api(format!("{status}: {text}")));
        }

        let data: serde_json::Value = response
            .json()
            .await
            .map_err(|e| LlmError::Api(e.to_string()))?;

        data["content"][0]["text"]
            .as_str()
            .map(std::string::ToString::to_string)
            .ok_or_else(|| LlmError::Api("No content in response".to_string()))
    }

    fn provider_name(&self) -> &str {
        "anthropic"
    }
}
