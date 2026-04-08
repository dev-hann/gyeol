import { useEffect, useState } from "react";
import { useAppStore } from "../stores/appStore";
import { Plus, Trash2, Save } from "lucide-react";
import type { WorkerDefinition } from "../types";
import { cn } from "../lib/utils";

interface WorkerFormData {
  name: string;
  layer_name: string;
  system_prompt: string;
  model: string;
  temperature: number;
  max_tokens: number;
  enabled: boolean;
}

const emptyForm: WorkerFormData = {
  name: "",
  layer_name: "",
  system_prompt: "",
  model: "",
  temperature: 0.7,
  max_tokens: 4096,
  enabled: true,
};

export function WorkersPage() {
  const { workers, layers, fetchWorkers, fetchLayers, saveWorker, deleteWorker } =
    useAppStore();
  const [editing, setEditing] = useState<WorkerFormData | null>(null);
  const [isNew, setIsNew] = useState(false);

  useEffect(() => {
    fetchWorkers();
    fetchLayers();
  }, [fetchWorkers, fetchLayers]);

  const handleNew = () => {
    setEditing({ ...emptyForm });
    setIsNew(true);
  };

  const handleEdit = (worker: WorkerDefinition) => {
    setEditing({
      name: worker.name,
      layer_name: worker.layer_name,
      system_prompt: worker.system_prompt,
      model: worker.model || "",
      temperature: worker.temperature ?? 0.7,
      max_tokens: worker.max_tokens ?? 4096,
      enabled: worker.enabled,
    });
    setIsNew(false);
  };

  const handleSave = async () => {
    if (!editing) return;
    await saveWorker({
      name: editing.name,
      layer_name: editing.layer_name,
      system_prompt: editing.system_prompt,
      model: editing.model || null,
      temperature: editing.temperature,
      max_tokens: editing.max_tokens,
      enabled: editing.enabled,
    });
    setEditing(null);
    setIsNew(false);
  };

  const handleDelete = async (name: string) => {
    await deleteWorker(name);
    if (editing?.name === name) {
      setEditing(null);
      setIsNew(false);
    }
  };

  return (
    <div className="p-6 space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-xl font-semibold">Workers</h2>
          <p className="text-sm text-[var(--text-muted)] mt-1">
            Configure AI worker agents for each layer
          </p>
        </div>
        <button
          onClick={handleNew}
          className="flex items-center gap-1.5 px-3 py-1.5 bg-[var(--accent)] hover:bg-[var(--accent-hover)] text-white text-sm rounded-md transition-colors"
        >
          <Plus size={14} />
          Add Worker
        </button>
      </div>

      {editing && (
        <div className="bg-[var(--bg-secondary)] border border-[var(--border)] rounded-lg p-4 space-y-4">
          <h3 className="text-sm font-medium">
            {isNew ? "New Worker" : `Edit: ${editing.name}`}
          </h3>
          <div className="grid grid-cols-3 gap-4">
            <div>
              <label className="block text-xs text-[var(--text-muted)] mb-1">
                Name
              </label>
              <input
                value={editing.name}
                onChange={(e) =>
                  setEditing({ ...editing, name: e.target.value })
                }
                disabled={!isNew}
                className="w-full px-3 py-1.5 bg-[var(--bg-tertiary)] border border-[var(--border)] rounded-md text-sm text-[var(--text-primary)] disabled:opacity-50"
              />
            </div>
            <div>
              <label className="block text-xs text-[var(--text-muted)] mb-1">
                Layer
              </label>
              <select
                value={editing.layer_name}
                onChange={(e) =>
                  setEditing({ ...editing, layer_name: e.target.value })
                }
                className="w-full px-3 py-1.5 bg-[var(--bg-tertiary)] border border-[var(--border)] rounded-md text-sm text-[var(--text-primary)]"
              >
                <option value="">Select layer...</option>
                {layers.map((l) => (
                  <option key={l.name} value={l.name}>
                    {l.name}
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label className="block text-xs text-[var(--text-muted)] mb-1">
                Model Override (optional)
              </label>
              <input
                value={editing.model}
                onChange={(e) =>
                  setEditing({ ...editing, model: e.target.value })
                }
                placeholder="gpt-4o"
                className="w-full px-3 py-1.5 bg-[var(--bg-tertiary)] border border-[var(--border)] rounded-md text-sm text-[var(--text-primary)]"
              />
            </div>
            <div>
              <label className="block text-xs text-[var(--text-muted)] mb-1">
                Temperature
              </label>
              <input
                type="number"
                step="0.1"
                min="0"
                max="2"
                value={editing.temperature}
                onChange={(e) =>
                  setEditing({
                    ...editing,
                    temperature: parseFloat(e.target.value) || 0,
                  })
                }
                className="w-full px-3 py-1.5 bg-[var(--bg-tertiary)] border border-[var(--border)] rounded-md text-sm text-[var(--text-primary)]"
              />
            </div>
            <div>
              <label className="block text-xs text-[var(--text-muted)] mb-1">
                Max Tokens
              </label>
              <input
                type="number"
                value={editing.max_tokens}
                onChange={(e) =>
                  setEditing({
                    ...editing,
                    max_tokens: parseInt(e.target.value) || 0,
                  })
                }
                className="w-full px-3 py-1.5 bg-[var(--bg-tertiary)] border border-[var(--border)] rounded-md text-sm text-[var(--text-primary)]"
              />
            </div>
            <div className="flex items-end">
              <label className="flex items-center gap-2 text-sm">
                <input
                  type="checkbox"
                  checked={editing.enabled}
                  onChange={(e) =>
                    setEditing({ ...editing, enabled: e.target.checked })
                  }
                  className="accent-[var(--accent)]"
                />
                Enabled
              </label>
            </div>
          </div>
          <div>
            <label className="block text-xs text-[var(--text-muted)] mb-1">
              System Prompt
            </label>
            <textarea
              value={editing.system_prompt}
              onChange={(e) =>
                setEditing({ ...editing, system_prompt: e.target.value })
              }
              rows={4}
              className="w-full px-3 py-2 bg-[var(--bg-tertiary)] border border-[var(--border)] rounded-md text-sm text-[var(--text-primary)] font-mono resize-y"
              placeholder="You are an expert AI assistant..."
            />
          </div>
          <div className="flex items-center gap-2 justify-end">
            <button
              onClick={() => setEditing(null)}
              className="px-3 py-1.5 text-sm text-[var(--text-secondary)] hover:text-[var(--text-primary)] transition-colors"
            >
              Cancel
            </button>
            <button
              onClick={handleSave}
              disabled={!editing.name || !editing.layer_name}
              className="flex items-center gap-1.5 px-3 py-1.5 bg-[var(--accent)] hover:bg-[var(--accent-hover)] text-white text-sm rounded-md transition-colors disabled:opacity-50"
            >
              <Save size={14} />
              Save
            </button>
          </div>
        </div>
      )}

      <div className="space-y-2">
        {workers.map((worker) => (
          <div
            key={worker.name}
            className="bg-[var(--bg-secondary)] border border-[var(--border)] rounded-lg p-4"
          >
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div
                  className={cn(
                    "w-2 h-2 rounded-full",
                    worker.enabled ? "bg-green-400" : "bg-zinc-500"
                  )}
                />
                <div>
                  <h4 className="text-sm font-medium">{worker.name}</h4>
                  <div className="text-xs text-[var(--text-muted)] mt-0.5">
                    Layer: {worker.layer_name}
                    {worker.model && ` | Model: ${worker.model}`}
                    {" | "}
                    Temp: {worker.temperature ?? "default"}, Tokens:{" "}
                    {worker.max_tokens ?? "default"}
                  </div>
                </div>
              </div>
              <div className="flex items-center gap-1">
                <button
                  onClick={() => handleEdit(worker)}
                  className="p-1.5 text-[var(--text-muted)] hover:text-[var(--text-primary)] hover:bg-[var(--bg-hover)] rounded transition-colors"
                >
                  Edit
                </button>
                <button
                  onClick={() => handleDelete(worker.name)}
                  className="p-1.5 text-[var(--text-muted)] hover:text-red-400 hover:bg-[var(--bg-hover)] rounded transition-colors"
                >
                  <Trash2 size={14} />
                </button>
              </div>
            </div>
            <div className="mt-2 px-5 text-xs text-[var(--text-muted)] font-mono line-clamp-2 bg-[var(--bg-tertiary)] rounded p-2">
              {worker.system_prompt}
            </div>
          </div>
        ))}
        {workers.length === 0 && (
          <div className="text-center py-12 text-sm text-[var(--text-muted)]">
            No workers configured. Click "Add Worker" to create one.
          </div>
        )}
      </div>
    </div>
  );
}
