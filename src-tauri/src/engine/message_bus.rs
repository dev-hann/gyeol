use std::sync::Arc;
use std::collections::HashMap;
use parking_lot::Mutex;
use crate::engine::task::Task;

type HandlerFn = Box<dyn Fn(&Task) + Send + Sync>;

pub struct MessageBus {
    subscribers: Arc<Mutex<HashMap<String, Vec<HandlerFn>>>>,
}

impl MessageBus {
    pub fn new() -> Self {
        Self {
            subscribers: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    pub fn publish(&self, task: &Task) {
        let subs = self.subscribers.lock();
        if let Some(handlers) = subs.get(&task.task_type) {
            for handler in handlers {
                handler(task);
            }
        }
        if let Some(handlers) = subs.get("*") {
            for handler in handlers {
                handler(task);
            }
        }
    }

    #[allow(dead_code)]
    pub fn subscribe(&self, task_type: &str, handler: impl Fn(&Task) + Send + Sync + 'static) {
        self.subscribers
            .lock()
            .entry(task_type.to_string())
            .or_default()
            .push(Box::new(handler));
    }
}
