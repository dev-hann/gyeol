use rusqlite::{params, Connection, Result as SqlResult};
use std::path::Path;
use std::sync::Mutex;
use crate::engine::task::{Task, TaskPriority, TaskStatus};
use crate::engine::layer::LayerDefinition;
use crate::engine::worker::WorkerDefinition;
use crate::providers::ProviderSettings;

pub struct SqliteStore {
    conn: Mutex<Connection>,
}

impl SqliteStore {
    pub fn new(db_path: &Path) -> SqlResult<Self> {
        let conn = Connection::open(db_path)?;
        let store = Self {
            conn: Mutex::new(conn),
        };
        store.init_tables()?;
        Ok(store)
    }

    pub fn new_in_memory() -> SqlResult<Self> {
        let conn = Connection::open_in_memory()?;
        let store = Self {
            conn: Mutex::new(conn),
        };
        store.init_tables()?;
        Ok(store)
    }

    fn init_tables(&self) -> SqlResult<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute_batch(
            "
            CREATE TABLE IF NOT EXISTS tasks (
                id TEXT PRIMARY KEY,
                task_type TEXT NOT NULL,
                payload TEXT NOT NULL,
                priority TEXT NOT NULL,
                status TEXT NOT NULL,
                retry_count INTEGER DEFAULT 0,
                max_retries INTEGER DEFAULT 3,
                depth INTEGER DEFAULT 0,
                parent_task_id TEXT,
                layer_name TEXT,
                worker_name TEXT,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
            );

            CREATE TABLE IF NOT EXISTS layers (
                name TEXT PRIMARY KEY,
                input_types TEXT NOT NULL,
                output_types TEXT NOT NULL,
                worker_names TEXT NOT NULL,
                sort_order INTEGER DEFAULT 0,
                enabled INTEGER DEFAULT 1
            );

            CREATE TABLE IF NOT EXISTS workers (
                name TEXT PRIMARY KEY,
                layer_name TEXT NOT NULL,
                system_prompt TEXT NOT NULL,
                model TEXT,
                temperature REAL,
                max_tokens INTEGER,
                enabled INTEGER DEFAULT 1
            );

            CREATE TABLE IF NOT EXISTS settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS execution_logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                task_id TEXT NOT NULL,
                worker_name TEXT,
                status TEXT NOT NULL,
                message TEXT,
                created_at INTEGER NOT NULL
            );
            "
        )?;
        Ok(())
    }

    pub fn save_task(&self, task: &Task) -> SqlResult<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "INSERT OR REPLACE INTO tasks (id, task_type, payload, priority, status, retry_count, max_retries, depth, parent_task_id, layer_name, worker_name, created_at, updated_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13)",
            params![
                task.id,
                task.task_type,
                task.payload.to_string(),
                task.priority.as_str(),
                task.status.as_str(),
                task.retry_count,
                task.max_retries,
                task.depth,
                task.parent_task_id,
                task.layer_name,
                task.worker_name,
                task.created_at,
                task.updated_at,
            ],
        )?;
        Ok(())
    }

    pub fn get_task(&self, id: &str) -> SqlResult<Option<Task>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT id, task_type, payload, priority, status, retry_count, max_retries, depth, parent_task_id, layer_name, worker_name, created_at, updated_at FROM tasks WHERE id = ?1"
        )?;
        let task = stmt.query_row(params![id], |row| {
            Ok(row_to_task(row))
        }).ok();
        Ok(task)
    }

    pub fn list_tasks(&self, limit: usize, offset: usize) -> SqlResult<Vec<Task>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT id, task_type, payload, priority, status, retry_count, max_retries, depth, parent_task_id, layer_name, worker_name, created_at, updated_at FROM tasks ORDER BY created_at DESC LIMIT ?1 OFFSET ?2"
        )?;
        let tasks = stmt.query_map(params![limit, offset], |row| {
            Ok(row_to_task(row))
        })?.filter_map(|t| t.ok()).collect();
        Ok(tasks)
    }

    pub fn update_task_status(&self, id: &str, status: &str) -> SqlResult<()> {
        let conn = self.conn.lock().unwrap();
        let now = chrono::Utc::now().timestamp_millis();
        conn.execute(
            "UPDATE tasks SET status = ?1, updated_at = ?2 WHERE id = ?3",
            params![status, now, id],
        )?;
        Ok(())
    }

    pub fn save_layer(&self, layer: &LayerDefinition) -> SqlResult<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "INSERT OR REPLACE INTO layers (name, input_types, output_types, worker_names, sort_order, enabled)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
            params![
                layer.name,
                serde_json::to_string(&layer.input_types).unwrap(),
                serde_json::to_string(&layer.output_types).unwrap(),
                serde_json::to_string(&layer.worker_names).unwrap(),
                layer.order,
                layer.enabled as i32,
            ],
        )?;
        Ok(())
    }

    pub fn list_layers(&self) -> SqlResult<Vec<LayerDefinition>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT name, input_types, output_types, worker_names, sort_order, enabled FROM layers ORDER BY sort_order"
        )?;
        let layers = stmt.query_map([], |row| {
            Ok(LayerDefinition {
                name: row.get(0)?,
                input_types: serde_json::from_str(&row.get::<_, String>(1)?).unwrap(),
                output_types: serde_json::from_str(&row.get::<_, String>(2)?).unwrap(),
                worker_names: serde_json::from_str(&row.get::<_, String>(3)?).unwrap(),
                order: row.get(4)?,
                enabled: row.get::<_, i32>(5)? != 0,
            })
        })?.filter_map(|l| l.ok()).collect();
        Ok(layers)
    }

    pub fn delete_layer(&self, name: &str) -> SqlResult<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute("DELETE FROM layers WHERE name = ?1", params![name])?;
        Ok(())
    }

    pub fn save_worker(&self, worker: &WorkerDefinition) -> SqlResult<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "INSERT OR REPLACE INTO workers (name, layer_name, system_prompt, model, temperature, max_tokens, enabled)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
            params![
                worker.name,
                worker.layer_name,
                worker.system_prompt,
                worker.model,
                worker.temperature,
                worker.max_tokens,
                worker.enabled as i32,
            ],
        )?;
        Ok(())
    }

    pub fn get_worker(&self, name: &str) -> SqlResult<Option<WorkerDefinition>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT name, layer_name, system_prompt, model, temperature, max_tokens, enabled FROM workers WHERE name = ?1"
        )?;
        let worker = stmt.query_row(params![name], |row| {
            Ok(WorkerDefinition {
                name: row.get(0)?,
                layer_name: row.get(1)?,
                system_prompt: row.get(2)?,
                model: row.get(3)?,
                temperature: row.get(4)?,
                max_tokens: row.get(5)?,
                enabled: row.get::<_, i32>(6)? != 0,
            })
        }).ok();
        Ok(worker)
    }

    pub fn list_workers(&self) -> SqlResult<Vec<WorkerDefinition>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT name, layer_name, system_prompt, model, temperature, max_tokens, enabled FROM workers"
        )?;
        let workers = stmt.query_map([], |row| {
            Ok(WorkerDefinition {
                name: row.get(0)?,
                layer_name: row.get(1)?,
                system_prompt: row.get(2)?,
                model: row.get(3)?,
                temperature: row.get(4)?,
                max_tokens: row.get(5)?,
                enabled: row.get::<_, i32>(6)? != 0,
            })
        })?.filter_map(|w| w.ok()).collect();
        Ok(workers)
    }

    pub fn delete_worker(&self, name: &str) -> SqlResult<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute("DELETE FROM workers WHERE name = ?1", params![name])?;
        Ok(())
    }

    pub fn save_settings(&self, settings: &ProviderSettings) -> SqlResult<()> {
        let conn = self.conn.lock().unwrap();
        let json = serde_json::to_string(settings).unwrap();
        conn.execute(
            "INSERT OR REPLACE INTO settings (key, value) VALUES ('provider', ?1)",
            params![json],
        )?;
        Ok(())
    }

    pub fn get_settings(&self) -> SqlResult<ProviderSettings> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare("SELECT value FROM settings WHERE key = 'provider'")?;
        let result = stmt.query_row([], |row| {
            let val: String = row.get(0)?;
            Ok(val)
        }).ok();

        match result {
            Some(json) => {
                serde_json::from_str(&json)
                    .map_err(|e| rusqlite::Error::ToSqlConversionFailure(Box::new(e)))
            }
            None => Ok(ProviderSettings::default()),
        }
    }

    pub fn log_execution(&self, task_id: &str, worker_name: Option<&str>, status: &str, message: Option<&str>) -> SqlResult<()> {
        let conn = self.conn.lock().unwrap();
        let now = chrono::Utc::now().timestamp_millis();
        conn.execute(
            "INSERT INTO execution_logs (task_id, worker_name, status, message, created_at) VALUES (?1, ?2, ?3, ?4, ?5)",
            params![task_id, worker_name, status, message, now],
        )?;
        Ok(())
    }

    pub fn list_execution_logs(&self, task_id: Option<&str>, limit: usize) -> SqlResult<Vec<ExecutionLog>> {
        let conn = self.conn.lock().unwrap();
        let logs: Vec<ExecutionLog> = if let Some(tid) = task_id {
            let mut stmt = conn.prepare(
                "SELECT id, task_id, worker_name, status, message, created_at FROM execution_logs WHERE task_id = ?1 ORDER BY created_at DESC LIMIT ?2"
            )?;
            let rows = stmt.query_map(params![tid, limit], |row| {
                Ok(ExecutionLog {
                    id: row.get(0)?,
                    task_id: row.get(1)?,
                    worker_name: row.get(2)?,
                    status: row.get(3)?,
                    message: row.get(4)?,
                    created_at: row.get(5)?,
                })
            })?;
            rows.filter_map(|l| l.ok()).collect()
        } else {
            let mut stmt = conn.prepare(
                "SELECT id, task_id, worker_name, status, message, created_at FROM execution_logs ORDER BY created_at DESC LIMIT ?1"
            )?;
            let rows = stmt.query_map(params![limit], |row| {
                Ok(ExecutionLog {
                    id: row.get(0)?,
                    task_id: row.get(1)?,
                    worker_name: row.get(2)?,
                    status: row.get(3)?,
                    message: row.get(4)?,
                    created_at: row.get(5)?,
                })
            })?;
            rows.filter_map(|l| l.ok()).collect()
        };
        Ok(logs)
    }
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct ExecutionLog {
    pub id: i64,
    pub task_id: String,
    pub worker_name: Option<String>,
    pub status: String,
    pub message: Option<String>,
    pub created_at: i64,
}

fn row_to_task(row: &rusqlite::Row) -> Task {
    let priority_str: String = row.get(3).unwrap();
    let status_str: String = row.get(4).unwrap();
    let payload_str: String = row.get(2).unwrap();

    Task {
        id: row.get(0).unwrap(),
        task_type: row.get(1).unwrap(),
        payload: serde_json::from_str(&payload_str).unwrap_or(serde_json::Value::Null),
        priority: match priority_str.as_str() {
            "high" => TaskPriority::High,
            "medium" => TaskPriority::Medium,
            _ => TaskPriority::Low,
        },
        status: match status_str.as_str() {
            "pending" => TaskStatus::Pending,
            "running" => TaskStatus::Running,
            "done" => TaskStatus::Done,
            "failed" => TaskStatus::Failed,
            _ => TaskStatus::Pending,
        },
        retry_count: row.get(5).unwrap(),
        max_retries: row.get(6).unwrap(),
        depth: row.get(7).unwrap(),
        parent_task_id: row.get(8).unwrap(),
        layer_name: row.get(9).unwrap(),
        worker_name: row.get(10).unwrap(),
        created_at: row.get(11).unwrap(),
        updated_at: row.get(12).unwrap(),
    }
}
