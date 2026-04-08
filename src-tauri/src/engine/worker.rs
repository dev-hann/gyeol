use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use crate::engine::task::{Task, WorkerResult};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WorkerDefinition {
    pub name: String,
    pub layer_name: String,
    pub system_prompt: String,
    pub model: Option<String>,
    pub temperature: Option<f64>,
    pub max_tokens: Option<u32>,
    pub enabled: bool,
}

impl WorkerDefinition {
    #[allow(dead_code)]
    pub fn new(name: &str, layer_name: &str, system_prompt: &str) -> Self {
        Self {
            name: name.to_string(),
            layer_name: layer_name.to_string(),
            system_prompt: system_prompt.to_string(),
            model: None,
            temperature: None,
            max_tokens: None,
            enabled: true,
        }
    }
}

#[allow(dead_code)]
#[async_trait]
pub trait WorkerHandler: Send + Sync {
    async fn handle(&self, task: &Task, context: &WorkerContext) -> WorkerResult;
    fn name(&self) -> &str;
}

#[allow(dead_code)]
pub struct WorkerContext {
    pub state_store: crate::store::sqlite::SqliteStore,
    pub message_bus: crate::engine::message_bus::MessageBus,
    pub provider: Box<dyn crate::providers::LlmProvider>,
}
