pub mod openai;
pub mod anthropic;
pub mod ollama;

use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use std::fmt;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProviderSettings {
    pub provider: ProviderType,
    pub openai_api_key: String,
    pub openai_model: String,
    pub anthropic_api_key: String,
    pub anthropic_model: String,
    pub ollama_base_url: String,
    pub ollama_model: String,
    pub default_temperature: f64,
    pub default_max_tokens: u32,
}

impl Default for ProviderSettings {
    fn default() -> Self {
        Self {
            provider: ProviderType::OpenAI,
            openai_api_key: String::new(),
            openai_model: "gpt-4o".to_string(),
            anthropic_api_key: String::new(),
            anthropic_model: "claude-sonnet-4-20250514".to_string(),
            ollama_base_url: "http://localhost:11434".to_string(),
            ollama_model: "llama3".to_string(),
            default_temperature: 0.7,
            default_max_tokens: 4096,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum ProviderType {
    OpenAI,
    Anthropic,
    Ollama,
}

impl fmt::Display for ProviderType {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ProviderType::OpenAI => write!(f, "openai"),
            ProviderType::Anthropic => write!(f, "anthropic"),
            ProviderType::Ollama => write!(f, "ollama"),
        }
    }
}

#[derive(Debug, thiserror::Error)]
pub enum LlmError {
    #[error("API error: {0}")]
    Api(String),
    #[error("Network error: {0}")]
    Network(String),
    #[error("Configuration error: {0}")]
    Config(String),
}

#[async_trait]
pub trait LlmProvider: Send + Sync {
    async fn generate(&self, prompt: &str) -> Result<String, LlmError>;
    async fn generate_with_system(&self, system: &str, user: &str) -> Result<String, LlmError>;
    fn provider_name(&self) -> &str;
}

pub fn create_provider(settings: &ProviderSettings) -> Box<dyn LlmProvider> {
    match settings.provider {
        ProviderType::OpenAI => Box::new(openai::OpenAIProvider::new(
            &settings.openai_api_key,
            &settings.openai_model,
            settings.default_temperature,
            settings.default_max_tokens,
        )),
        ProviderType::Anthropic => Box::new(anthropic::AnthropicProvider::new(
            &settings.anthropic_api_key,
            &settings.anthropic_model,
            settings.default_temperature,
            settings.default_max_tokens,
        )),
        ProviderType::Ollama => Box::new(ollama::OllamaProvider::new(
            &settings.ollama_base_url,
            &settings.ollama_model,
            settings.default_temperature,
            settings.default_max_tokens,
        )),
    }
}
