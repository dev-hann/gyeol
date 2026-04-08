use std::sync::Arc;
use crate::engine::scheduler::Scheduler;
use crate::engine::layer::LayerRegistry;
use crate::store::sqlite::SqliteStore;

pub struct AppState {
    pub scheduler: Arc<Scheduler>,
    pub store: Arc<SqliteStore>,
    pub layer_registry: Arc<LayerRegistry>,
}
