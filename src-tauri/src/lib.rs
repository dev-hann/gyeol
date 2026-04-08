mod commands;
mod engine;
mod providers;
mod state;
mod store;

use std::sync::Arc;
use state::AppState;
use store::sqlite::SqliteStore;
use engine::queue::TaskQueue;
use engine::layer::LayerRegistry;
use engine::message_bus::MessageBus;
use engine::scheduler::Scheduler;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
#[allow(clippy::missing_panics_doc)]
pub fn run() {
    let app_data_dir = dirs_data_dir();
    std::fs::create_dir_all(&app_data_dir).ok();

    let db_path = std::path::Path::new(&app_data_dir).join("gyeol.db");
    let store = Arc::new(SqliteStore::new(&db_path).unwrap_or_else(|e| {
        eprintln!("Failed to open database at {}: {e}", db_path.display());
        std::process::exit(1);
    }));

    let queue = Arc::new(TaskQueue::new());
    let layer_registry = Arc::new(LayerRegistry::new());
    let message_bus = Arc::new(MessageBus::new());

    let layers = store.list_layers().unwrap_or_default();
    for layer in &layers {
        layer_registry.register(layer.clone());
    }

    let scheduler = Arc::new(Scheduler::new(queue, layer_registry.clone(), message_bus, store.clone()));

    let app_state = AppState {
        scheduler,
        store,
        layer_registry,
    };

    tauri::Builder::default()
        .manage(app_state)
        .setup(|app| {
            if cfg!(debug_assertions) {
                app.handle().plugin(
                    tauri_plugin_log::Builder::default()
                        .level(log::LevelFilter::Info)
                        .build(),
                )?;
            }
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            commands::task::create_task,
            commands::task::list_tasks,
            commands::task::get_task,
            commands::task::get_queue_size,
            commands::layer::list_layers,
            commands::layer::save_layer,
            commands::layer::delete_layer,
            commands::worker::list_workers,
            commands::worker::save_worker,
            commands::worker::delete_worker,
            commands::worker::get_worker,
            commands::execution::run_scheduler,
            commands::execution::list_execution_logs,
            commands::settings::get_settings,
            commands::settings::save_settings,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

fn dirs_data_dir() -> String {
    let home = std::env::var("HOME").unwrap_or_else(|_| ".".to_string());
    format!("{home}/.local/share/gyeol")
}
