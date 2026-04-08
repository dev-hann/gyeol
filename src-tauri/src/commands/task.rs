use crate::engine::task::{Task, TaskPriority};
use crate::state::AppState;
use serde::Deserialize;
use tauri::State;

#[derive(Deserialize)]
pub struct CreateTaskPayload {
    pub task_type: String,
    pub payload: serde_json::Value,
    pub priority: Option<String>,
}

#[tauri::command]
pub fn create_task(payload: CreateTaskPayload, state: State<'_, AppState>) -> Result<String, String> {
    let priority = match payload.priority.as_deref() {
        Some("high") => TaskPriority::High,
        Some("medium") => TaskPriority::Medium,
        _ => TaskPriority::Low,
    };
    let task = Task::new(&payload.task_type, payload.payload, priority);
    let id = task.id.clone();
    state.scheduler.submit(task);
    Ok(id)
}

#[tauri::command]
pub fn list_tasks(limit: Option<usize>, offset: Option<usize>, state: State<'_, AppState>) -> Result<Vec<Task>, String> {
    state.store.list_tasks(limit.unwrap_or(50), offset.unwrap_or(0))
        .map_err(|e: rusqlite::Error| e.to_string())
}

#[tauri::command]
pub fn get_task(id: String, state: State<'_, AppState>) -> Result<Option<Task>, String> {
    state.store.get_task(&id).map_err(|e: rusqlite::Error| e.to_string())
}

#[tauri::command]
pub fn get_queue_size(state: State<'_, AppState>) -> Result<usize, String> {
    Ok(state.scheduler.queue_len())
}
