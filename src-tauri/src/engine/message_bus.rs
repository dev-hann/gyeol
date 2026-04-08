use std::sync::Arc;
use std::collections::HashMap;
use parking_lot::Mutex;
use crate::engine::task::Task;

type HandlerFn = Arc<dyn Fn(&Task) + Send + Sync>;

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
        let (specific, wildcard) = {
            let subs = self.subscribers.lock();
            (
                subs.get(&task.task_type).cloned().unwrap_or_default(),
                subs.get("*").cloned().unwrap_or_default(),
            )
        };
        for handler in &specific {
            handler(task);
        }
        for handler in &wildcard {
            handler(task);
        }
    }

    #[allow(dead_code)]
    pub fn subscribe(&self, task_type: &str, handler: impl Fn(&Task) + Send + Sync + 'static) {
        self.subscribers
            .lock()
            .entry(task_type.to_string())
            .or_default()
            .push(Arc::new(handler));
    }
}
