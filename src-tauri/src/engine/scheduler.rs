use std::sync::Arc;
use parking_lot::Mutex;
use tokio::task::JoinSet;
use crate::engine::task::{Task, TaskStatus, WorkerResult};
use crate::engine::queue::TaskQueue;
use crate::engine::layer::LayerRegistry;
use crate::engine::message_bus::MessageBus;
use crate::store::sqlite::SqliteStore;

const MAX_EXECUTION_DEPTH: u32 = 10;

#[derive(Clone)]
pub struct Scheduler {
    queue: Arc<TaskQueue>,
    layer_registry: Arc<LayerRegistry>,
    message_bus: Arc<MessageBus>,
    store: Arc<SqliteStore>,
    running: Arc<Mutex<bool>>,
    max_concurrent: usize,
}

impl Scheduler {
    pub fn new(
        queue: Arc<TaskQueue>,
        layer_registry: Arc<LayerRegistry>,
        message_bus: Arc<MessageBus>,
        store: Arc<SqliteStore>,
    ) -> Self {
        Self {
            queue,
            layer_registry,
            message_bus,
            store,
            running: Arc::new(Mutex::new(false)),
            max_concurrent: 4,
        }
    }

    pub fn submit(&self, task: Task) -> String {
        let id = task.id.clone();
        self.queue.push(task);
        id
    }

    pub async fn run_once(&self) -> Vec<WorkerResult> {
        let mut results = Vec::new();
        let mut join_set: JoinSet<WorkerResult> = JoinSet::new();
        let mut taken = 0;

        while taken < self.max_concurrent {
            let task = match self.queue.pop() {
                Some(t) => t,
                None => break,
            };

            if task.depth > MAX_EXECUTION_DEPTH {
                log::warn!("Task {} exceeded max depth", task.id);
                continue;
            }

            let layers = self.layer_registry.find_by_input_type(&task.task_type);
            if layers.is_empty() {
                log::warn!("No layer found for task type: {}", task.task_type);
                continue;
            }

            let layer = &layers[0];
            let mut task = task;
            task.status = TaskStatus::Running;
            task.layer_name = Some(layer.name.clone());
            let _ = self.store.save_task(&task);

            for worker_name in &layer.worker_names {
                if taken >= self.max_concurrent {
                    break;
                }
                let t = task.clone();
                let w_name = worker_name.clone();
                let store = self.store.clone();

                join_set.spawn(async move {
                    execute_worker(&t, &w_name, &store).await
                });
                taken += 1;
            }
        }

        while let Some(res) = join_set.join_next().await {
            match res {
                Ok(worker_result) => {
                    if worker_result.success {
                        for output_task in &worker_result.output_tasks {
                            self.queue.push(output_task.clone());
                            self.message_bus.publish(output_task);
                        }
                    }
                    results.push(worker_result);
                }
                Err(e) => {
                    log::error!("Worker task panicked: {}", e);
                }
            }
        }

        results
    }

    pub fn queue_len(&self) -> usize {
        self.queue.len()
    }

    pub fn is_running(&self) -> bool {
        *self.running.lock()
    }

    pub fn set_running(&self, val: bool) {
        *self.running.lock() = val;
    }
}

async fn execute_worker(task: &Task, worker_name: &str, store: &SqliteStore) -> WorkerResult {
    let worker_def = match store.get_worker(worker_name) {
        Ok(Some(w)) => w,
        Ok(None) => {
            return WorkerResult {
                success: false,
                output_tasks: vec![],
                error: Some(format!("Worker '{}' not found", worker_name)),
                metadata: None,
            };
        }
        Err(e) => {
            return WorkerResult {
                success: false,
                output_tasks: vec![],
                error: Some(format!("DB error: {}", e)),
                metadata: None,
            };
        }
    };

    let provider = match store.get_settings() {
        Ok(settings) => crate::providers::create_provider(&settings),
        Err(_) => crate::providers::create_provider(&crate::providers::ProviderSettings::default()),
    };

    let prompt = format!(
        "{}\n\nTask: {}\nPayload: {}",
        worker_def.system_prompt,
        task.task_type,
        task.payload
    );

    match provider.generate(&prompt).await {
        Ok(response) => {
            let mut output_task = Task::new(
                "analysis_result",
                serde_json::json!({ "worker": worker_name, "response": response }),
                task.priority.clone(),
            );
            output_task.depth = task.depth + 1;
            output_task.parent_task_id = Some(task.id.clone());

            WorkerResult {
                success: true,
                output_tasks: vec![output_task],
                error: None,
                metadata: Some(serde_json::json!({ "worker": worker_name })),
            }
        }
        Err(e) => WorkerResult {
            success: false,
            output_tasks: vec![],
            error: Some(e.to_string()),
            metadata: None,
        },
    }
}
