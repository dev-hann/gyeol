use crate::engine::worker::WorkerDefinition;
use crate::state::AppState;
use serde::Deserialize;
use tauri::State;

#[derive(Deserialize)]
pub struct SaveWorkerPayload {
    pub name: String,
    pub layer_name: String,
    pub system_prompt: String,
    pub model: Option<String>,
    pub temperature: Option<f64>,
    pub max_tokens: Option<u32>,
    pub enabled: Option<bool>,
}

#[tauri::command]
pub fn list_workers(state: State<'_, AppState>) -> Result<Vec<WorkerDefinition>, String> {
    state.store.list_workers().map_err(|e| e.to_string())
}

#[tauri::command]
pub fn save_worker(payload: SaveWorkerPayload, state: State<'_, AppState>) -> Result<(), String> {
    let worker = WorkerDefinition {
        name: payload.name,
        layer_name: payload.layer_name,
        system_prompt: payload.system_prompt,
        model: payload.model,
        temperature: payload.temperature,
        max_tokens: payload.max_tokens,
        enabled: payload.enabled.unwrap_or(true),
    };
    state.store.save_worker(&worker).map_err(|e| e.to_string())
}

#[tauri::command]
pub fn delete_worker(name: String, state: State<'_, AppState>) -> Result<(), String> {
    state.store.delete_worker(&name).map_err(|e| e.to_string())
}

#[tauri::command]
pub fn get_worker(name: String, state: State<'_, AppState>) -> Result<Option<WorkerDefinition>, String> {
    state.store.get_worker(&name).map_err(|e| e.to_string())
}
