#![allow(dead_code)]

use crate::engine::task::{Task, EvaluationResult};

pub trait Evaluator: Send + Sync {
    fn evaluate(&self, task: &Task, result: &str) -> EvaluationResult;
}

pub struct DefaultEvaluator {
    pub passing_score: f64,
}

impl DefaultEvaluator {
    pub fn new() -> Self {
        Self {
            passing_score: 0.7,
        }
    }
}

impl Evaluator for DefaultEvaluator {
    fn evaluate(&self, _task: &Task, result: &str) -> EvaluationResult {
        let has_content = !result.trim().is_empty();
        let score = if has_content { 1.0 } else { 0.0 };
        EvaluationResult {
            passed: score >= self.passing_score,
            score,
            reasons: if has_content {
                vec!["Output is non-empty".to_string()]
            } else {
                vec!["Output is empty".to_string()]
            },
        }
    }
}
