use std::collections::BinaryHeap;
use std::sync::Arc;
use parking_lot::Mutex;
use crate::engine::task::Task;

#[derive(Debug)]
struct PrioritizedTask {
    priority: u8,
    created_at: i64,
    task: Task,
}

impl PartialEq for PrioritizedTask {
    fn eq(&self, other: &Self) -> bool {
        self.priority == other.priority && self.created_at == other.created_at
    }
}

impl Eq for PrioritizedTask {}

impl PartialOrd for PrioritizedTask {
    fn partial_cmp(&self, other: &Self) -> Option<std::cmp::Ordering> {
        Some(self.cmp(other))
    }
}

impl Ord for PrioritizedTask {
    fn cmp(&self, other: &Self) -> std::cmp::Ordering {
        self.priority
            .cmp(&other.priority)
            .then_with(|| other.created_at.cmp(&self.created_at))
    }
}

pub struct TaskQueue {
    heap: Arc<Mutex<BinaryHeap<PrioritizedTask>>>,
}

impl TaskQueue {
    pub fn new() -> Self {
        Self {
            heap: Arc::new(Mutex::new(BinaryHeap::new())),
        }
    }

    pub fn push(&self, task: Task) {
        let p_task = PrioritizedTask {
            priority: task.priority.priority_value(),
            created_at: task.created_at,
            task,
        };
        self.heap.lock().push(p_task);
    }

    pub fn pop(&self) -> Option<Task> {
        self.heap.lock().pop().map(|p| p.task)
    }

    pub fn peek(&self) -> Option<Task> {
        self.heap.lock().peek().map(|p| p.task.clone())
    }

    pub fn len(&self) -> usize {
        self.heap.lock().len()
    }

    pub fn is_empty(&self) -> bool {
        self.heap.lock().is_empty()
    }

    pub fn drain_all(&self) -> Vec<Task> {
        let mut heap = self.heap.lock();
        let mut tasks = Vec::new();
        while let Some(p) = heap.pop() {
            tasks.push(p.task);
        }
        tasks
    }
}
