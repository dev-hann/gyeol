use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use parking_lot::Mutex;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LayerDefinition {
    pub name: String,
    pub input_types: Vec<String>,
    pub output_types: Vec<String>,
    pub worker_names: Vec<String>,
    pub order: u32,
    pub enabled: bool,
}

impl LayerDefinition {
    #[allow(dead_code)]
    pub fn new(name: &str, input_types: Vec<&str>, output_types: Vec<&str>, worker_names: Vec<&str>, order: u32) -> Self {
        Self {
            name: name.to_string(),
            input_types: input_types.into_iter().map(|s| s.to_string()).collect(),
            output_types: output_types.into_iter().map(|s| s.to_string()).collect(),
            worker_names: worker_names.into_iter().map(|s| s.to_string()).collect(),
            order,
            enabled: true,
        }
    }
}

pub struct LayerRegistry {
    layers: Arc<Mutex<HashMap<String, LayerDefinition>>>,
}

impl LayerRegistry {
    pub fn new() -> Self {
        Self {
            layers: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    pub fn register(&self, layer: LayerDefinition) {
        self.layers.lock().insert(layer.name.clone(), layer);
    }

    #[allow(dead_code)]
    pub fn get(&self, name: &str) -> Option<LayerDefinition> {
        self.layers.lock().get(name).cloned()
    }

    pub fn find_by_input_type(&self, task_type: &str) -> Vec<LayerDefinition> {
        let layers = self.layers.lock();
        let mut matched: Vec<LayerDefinition> = layers
            .values()
            .filter(|l| l.enabled && l.input_types.contains(&task_type.to_string()))
            .cloned()
            .collect();
        matched.sort_by_key(|l| l.order);
        matched
    }

    #[allow(dead_code)]
    pub fn list(&self) -> Vec<LayerDefinition> {
        let mut layers: Vec<LayerDefinition> = self.layers.lock().values().cloned().collect();
        layers.sort_by_key(|l| l.order);
        layers
    }

    pub fn remove(&self, name: &str) -> bool {
        self.layers.lock().remove(name).is_some()
    }

    #[allow(dead_code)]
    pub fn update(&self, layer: LayerDefinition) {
        self.layers.lock().insert(layer.name.clone(), layer);
    }
}
