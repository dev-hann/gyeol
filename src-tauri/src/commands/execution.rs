use crate::engine::task::WorkerResult;
use crate::state::AppState;
use crate::store::sqlite::ExecutionLog;
use tauri::State;

#[tauri::command]
pub async fn run_scheduler(state: State<'_, AppState>) -> Result<Vec<WorkerResult>, String> {
    let results = state.scheduler.run_once().await;
    for result in &results {
        let worker_name = result.metadata
            .as_ref()
            .and_then(|m| m.get("worker"))
            .and_then(|v| v.as_str());
        let _ = state.store.log_execution(
            "scheduler",
            worker_name,
            if result.success { "success" } else { "failed" },
            result.error.as_deref(),
        );
    }
    Ok(results)
}

#[tauri::command]
pub fn list_execution_logs(
    task_id: Option<String>,
    limit: Option<usize>,
    state: State<'_, AppState>,
) -> Result<Vec<ExecutionLog>, String> {
    state.store
        .list_execution_logs(task_id.as_deref(), limit.unwrap_or(100))
        .map_err(|e: rusqlite::Error| e.to_string())
}
