import { create } from "zustand";
import type {
  Task,
  LayerDefinition,
  WorkerDefinition,
  ExecutionLog,
  ProviderSettings,
} from "@/types";
import * as api from "@/lib/api";

interface AppState {
  tasks: Task[];
  layers: LayerDefinition[];
  workers: WorkerDefinition[];
  logs: ExecutionLog[];
  settings: ProviderSettings | null;
  queueSize: number;
  loading: boolean;
  error: string | null;

  fetchTasks: () => Promise<void>;
  fetchLayers: () => Promise<void>;
  fetchWorkers: () => Promise<void>;
  fetchLogs: (taskId?: string) => Promise<void>;
  fetchSettings: () => Promise<void>;
  fetchQueueSize: () => Promise<void>;
  createTask: (
    type: string,
    payload: unknown,
    priority?: string
  ) => Promise<string>;
  runScheduler: () => Promise<void>;
  saveLayer: (
    layer: Omit<LayerDefinition, "order" | "enabled"> & {
      order?: number;
      enabled?: boolean;
    }
  ) => Promise<void>;
  deleteLayer: (name: string) => Promise<void>;
  saveWorker: (
    worker: Omit<WorkerDefinition, "enabled"> & { enabled?: boolean }
  ) => Promise<void>;
  deleteWorker: (name: string) => Promise<void>;
  saveSettings: (settings: ProviderSettings) => Promise<void>;
  clearError: () => void;
}

export const useAppStore = create<AppState>((set, get) => ({
  tasks: [],
  layers: [],
  workers: [],
  logs: [],
  settings: null,
  queueSize: 0,
  loading: false,
  error: null,

  clearError: () => set({ error: null }),

  fetchTasks: async () => {
    try {
      const tasks = await api.listTasks(100);
      set({ tasks });
    } catch (e) {
      set({ error: String(e) });
    }
  },

  fetchLayers: async () => {
    try {
      const layers = await api.listLayers();
      set({ layers });
    } catch (e) {
      set({ error: String(e) });
    }
  },

  fetchWorkers: async () => {
    try {
      const workers = await api.listWorkers();
      set({ workers });
    } catch (e) {
      set({ error: String(e) });
    }
  },

  fetchLogs: async (taskId) => {
    try {
      const logs = await api.listExecutionLogs(taskId, 200);
      set({ logs });
    } catch (e) {
      set({ error: String(e) });
    }
  },

  fetchSettings: async () => {
    try {
      const settings = await api.getSettings();
      set({ settings });
    } catch (e) {
      set({ error: String(e) });
    }
  },

  fetchQueueSize: async () => {
    try {
      const queueSize = await api.getQueueSize();
      set({ queueSize });
    } catch (e) {
      set({ error: String(e) });
    }
  },

  createTask: async (type, payload, priority) => {
    set({ loading: true });
    try {
      const id = await api.createTask(type, payload, priority);
      await get().fetchQueueSize();
      await get().fetchTasks();
      set({ loading: false });
      return id;
    } catch (e) {
      set({ error: String(e), loading: false });
      throw e;
    }
  },

  runScheduler: async () => {
    set({ loading: true });
    try {
      await api.runScheduler();
      await Promise.all([
        get().fetchTasks(),
        get().fetchQueueSize(),
        get().fetchLogs(),
      ]);
      set({ loading: false });
    } catch (e) {
      set({ error: String(e), loading: false });
    }
  },

  saveLayer: async (layer) => {
    try {
      await api.saveLayer(layer);
      await get().fetchLayers();
    } catch (e) {
      set({ error: String(e) });
    }
  },

  deleteLayer: async (name) => {
    try {
      await api.deleteLayer(name);
      await get().fetchLayers();
    } catch (e) {
      set({ error: String(e) });
    }
  },

  saveWorker: async (worker) => {
    try {
      await api.saveWorker(worker);
      await get().fetchWorkers();
    } catch (e) {
      set({ error: String(e) });
    }
  },

  deleteWorker: async (name) => {
    try {
      await api.deleteWorker(name);
      await get().fetchWorkers();
    } catch (e) {
      set({ error: String(e) });
    }
  },

  saveSettings: async (settings) => {
    try {
      await api.saveSettings(settings);
      set({ settings });
    } catch (e) {
      set({ error: String(e) });
    }
  },
}));
