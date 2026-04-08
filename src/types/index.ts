export interface Task {
  id: string;
  task_type: string;
  payload: unknown;
  priority: "Low" | "Medium" | "High";
  status: "Pending" | "Running" | "Done" | "Failed";
  retry_count: number;
  max_retries: number;
  depth: number;
  parent_task_id: string | null;
  layer_name: string | null;
  worker_name: string | null;
  created_at: number;
  updated_at: number;
}

export interface LayerDefinition {
  name: string;
  input_types: string[];
  output_types: string[];
  worker_names: string[];
  order: number;
  enabled: boolean;
}

export interface WorkerDefinition {
  name: string;
  layer_name: string;
  system_prompt: string;
  model: string | null;
  temperature: number | null;
  max_tokens: number | null;
  enabled: boolean;
}

export interface ProviderSettings {
  provider: "OpenAI" | "Anthropic" | "Ollama";
  openai_api_key: string;
  openai_model: string;
  anthropic_api_key: string;
  anthropic_model: string;
  ollama_base_url: string;
  ollama_model: string;
  default_temperature: number;
  default_max_tokens: number;
}

export interface WorkerResult {
  success: boolean;
  output_tasks: Task[];
  error: string | null;
  metadata: Record<string, unknown> | null;
}

export interface ExecutionLog {
  id: number;
  task_id: string;
  worker_name: string | null;
  status: string;
  message: string | null;
  created_at: number;
}
