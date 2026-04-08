use crate::engine::layer::LayerDefinition;
use crate::state::AppState;
use serde::Deserialize;
use tauri::State;

#[derive(Deserialize)]
pub struct SaveLayerPayload {
    pub name: String,
    pub input_types: Vec<String>,
    pub output_types: Vec<String>,
    pub worker_names: Vec<String>,
    pub order: Option<u32>,
    pub enabled: Option<bool>,
}

#[tauri::command]
pub fn list_layers(state: State<'_, AppState>) -> Result<Vec<LayerDefinition>, String> {
    state.store.list_layers().map_err(|e: rusqlite::Error| e.to_string())
}

#[tauri::command]
pub fn save_layer(payload: SaveLayerPayload, state: State<'_, AppState>) -> Result<(), String> {
    let layer = LayerDefinition {
        name: payload.name,
        input_types: payload.input_types,
        output_types: payload.output_types,
        worker_names: payload.worker_names,
        order: payload.order.unwrap_or(0),
        enabled: payload.enabled.unwrap_or(true),
    };
    state.store.save_layer(&layer).map_err(|e: rusqlite::Error| e.to_string())?;
    state.layer_registry.register(layer);
    Ok(())
}

#[tauri::command]
pub fn delete_layer(name: String, state: State<'_, AppState>) -> Result<(), String> {
    state.store.delete_layer(&name).map_err(|e: rusqlite::Error| e.to_string())?;
    state.layer_registry.remove(&name);
    Ok(())
}
