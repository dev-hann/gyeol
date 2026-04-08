use crate::providers::ProviderSettings;
use crate::state::AppState;
use tauri::State;

#[tauri::command]
pub fn get_settings(state: State<'_, AppState>) -> Result<ProviderSettings, String> {
    state.store.get_settings().map_err(|e| e.to_string())
}

#[tauri::command]
pub fn save_settings(settings: ProviderSettings, state: State<'_, AppState>) -> Result<(), String> {
    state.store.save_settings(&settings).map_err(|e| e.to_string())
}
