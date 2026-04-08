import { invoke } from "@tauri-apps/api/core";
import type {
  Task,
  LayerDefinition,
  WorkerDefinition,
  ProviderSettings,
  WorkerResult,
  ExecutionLog,
} from "@/types";

export async function createTask(
  taskType: string,
  payload: unknown,
  priority?: string
): Promise<string> {
  return invoke<string>("create_task", {
    payload: { task_type: taskType, payload, priority },
  });
}

export async function listTasks(
  limit?: number,
  offset?: number
): Promise<Task[]> {
  return invoke<Task[]>("list_tasks", { limit, offset });
}

export async function getTask(id: string): Promise<Task | null> {
  return invoke<Task | null>("get_task", { id });
}

export async function getQueueSize(): Promise<number> {
  return invoke<number>("get_queue_size");
}

export async function listLayers(): Promise<LayerDefinition[]> {
  return invoke<LayerDefinition[]>("list_layers");
}

export async function saveLayer(
  layer: Omit<LayerDefinition, "order" | "enabled"> & {
    order?: number;
    enabled?: boolean;
  }
): Promise<void> {
  return invoke("save_layer", { payload: layer });
}

export async function deleteLayer(name: string): Promise<void> {
  return invoke("delete_layer", { name });
}

export async function listWorkers(): Promise<WorkerDefinition[]> {
  return invoke<WorkerDefinition[]>("list_workers");
}

export async function saveWorker(
  worker: Omit<WorkerDefinition, "enabled"> & { enabled?: boolean }
): Promise<void> {
  return invoke("save_worker", { payload: worker });
}

export async function deleteWorker(name: string): Promise<void> {
  return invoke("delete_worker", { name });
}

export async function runScheduler(): Promise<WorkerResult[]> {
  return invoke<WorkerResult[]>("run_scheduler");
}

export async function listExecutionLogs(
  taskId?: string,
  limit?: number
): Promise<ExecutionLog[]> {
  return invoke<ExecutionLog[]>("list_execution_logs", {
    taskId,
    limit,
  });
}

export async function getSettings(): Promise<ProviderSettings> {
  return invoke<ProviderSettings>("get_settings");
}

export async function saveSettings(
  settings: ProviderSettings
): Promise<void> {
  return invoke("save_settings", { settings });
}
