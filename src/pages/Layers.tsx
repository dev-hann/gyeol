import { useEffect, useState } from "react";
import { useAppStore } from "../stores/appStore";
import { Plus, Trash2, Save } from "lucide-react";
import type { LayerDefinition } from "../types";
import { cn } from "../lib/utils";

interface LayerFormData {
  name: string;
  input_types: string;
  output_types: string;
  worker_names: string;
  order: number;
  enabled: boolean;
}

const emptyForm: LayerFormData = {
  name: "",
  input_types: "",
  output_types: "",
  worker_names: "",
  order: 0,
  enabled: true,
};

export function LayersPage() {
  const { layers, fetchLayers, fetchWorkers, saveLayer, deleteLayer } =
    useAppStore();
  const [editing, setEditing] = useState<LayerFormData | null>(null);
  const [isNew, setIsNew] = useState(false);

  useEffect(() => {
    fetchLayers();
    fetchWorkers();
  }, [fetchLayers, fetchWorkers]);

  const handleNew = () => {
    setEditing({ ...emptyForm });
    setIsNew(true);
  };

  const handleEdit = (layer: LayerDefinition) => {
    setEditing({
      name: layer.name,
      input_types: layer.input_types.join(", "),
      output_types: layer.output_types.join(", "),
      worker_names: layer.worker_names.join(", "),
      order: layer.order,
      enabled: layer.enabled,
    });
    setIsNew(false);
  };

  const handleSave = async () => {
    if (!editing) return;
    await saveLayer({
      name: editing.name,
      input_types: editing.input_types
        .split(",")
        .map((s) => s.trim())
        .filter(Boolean),
      output_types: editing.output_types
        .split(",")
        .map((s) => s.trim())
        .filter(Boolean),
      worker_names: editing.worker_names
        .split(",")
        .map((s) => s.trim())
        .filter(Boolean),
      order: editing.order,
      enabled: editing.enabled,
    });
    setEditing(null);
    setIsNew(false);
  };

  const handleDelete = async (name: string) => {
    await deleteLayer(name);
    if (editing?.name === name) {
      setEditing(null);
      setIsNew(false);
    }
  };

  return (
    <div className="p-6 space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-xl font-semibold">Layers</h2>
          <p className="text-sm text-[var(--text-muted)] mt-1">
            Configure processing layers in your workflow pipeline
          </p>
        </div>
        <button
          onClick={handleNew}
          className="flex items-center gap-1.5 px-3 py-1.5 bg-[var(--accent)] hover:bg-[var(--accent-hover)] text-white text-sm rounded-md transition-colors"
        >
          <Plus size={14} />
          Add Layer
        </button>
      </div>

      {editing && (
        <div className="bg-[var(--bg-secondary)] border border-[var(--border)] rounded-lg p-4 space-y-4">
          <h3 className="text-sm font-medium">
            {isNew ? "New Layer" : `Edit: ${editing.name}`}
          </h3>
          <div className="grid grid-cols-2 gap-4">
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
                Order
              </label>
              <input
                type="number"
                value={editing.order}
                onChange={(e) =>
                  setEditing({
                    ...editing,
                    order: parseInt(e.target.value) || 0,
                  })
                }
                className="w-full px-3 py-1.5 bg-[var(--bg-tertiary)] border border-[var(--border)] rounded-md text-sm text-[var(--text-primary)]"
              />
            </div>
            <div>
              <label className="block text-xs text-[var(--text-muted)] mb-1">
                Input Types (comma-separated)
              </label>
              <input
                value={editing.input_types}
                onChange={(e) =>
                  setEditing({ ...editing, input_types: e.target.value })
                }
                placeholder="issue, question"
                className="w-full px-3 py-1.5 bg-[var(--bg-tertiary)] border border-[var(--border)] rounded-md text-sm text-[var(--text-primary)]"
              />
            </div>
            <div>
              <label className="block text-xs text-[var(--text-muted)] mb-1">
                Output Types (comma-separated)
              </label>
              <input
                value={editing.output_types}
                onChange={(e) =>
                  setEditing({ ...editing, output_types: e.target.value })
                }
                placeholder="plan, analysis"
                className="w-full px-3 py-1.5 bg-[var(--bg-tertiary)] border border-[var(--border)] rounded-md text-sm text-[var(--text-primary)]"
              />
            </div>
            <div className="col-span-2">
              <label className="block text-xs text-[var(--text-muted)] mb-1">
                Worker Names (comma-separated)
              </label>
              <input
                value={editing.worker_names}
                onChange={(e) =>
                  setEditing({ ...editing, worker_names: e.target.value })
                }
                placeholder="analyzer, planner"
                className="w-full px-3 py-1.5 bg-[var(--bg-tertiary)] border border-[var(--border)] rounded-md text-sm text-[var(--text-primary)]"
              />
            </div>
          </div>
          <div className="flex items-center gap-2">
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
            <div className="flex-1" />
            <button
              onClick={() => setEditing(null)}
              className="px-3 py-1.5 text-sm text-[var(--text-secondary)] hover:text-[var(--text-primary)] transition-colors"
            >
              Cancel
            </button>
            <button
              onClick={handleSave}
              disabled={!editing.name}
              className="flex items-center gap-1.5 px-3 py-1.5 bg-[var(--accent)] hover:bg-[var(--accent-hover)] text-white text-sm rounded-md transition-colors disabled:opacity-50"
            >
              <Save size={14} />
              Save
            </button>
          </div>
        </div>
      )}

      <div className="space-y-2">
        {layers.map((layer) => (
          <div
            key={layer.name}
            className="bg-[var(--bg-secondary)] border border-[var(--border)] rounded-lg p-4"
          >
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div
                  className={cn(
                    "w-2 h-2 rounded-full",
                    layer.enabled ? "bg-green-400" : "bg-zinc-500"
                  )}
                />
                <div>
                  <h4 className="text-sm font-medium">{layer.name}</h4>
                  <div className="text-xs text-[var(--text-muted)] mt-0.5">
                    Order: {layer.order} | Workers:{" "}
                    {layer.worker_names.join(", ") || "none"}
                  </div>
                </div>
              </div>
              <div className="flex items-center gap-1">
                <div className="text-xs text-[var(--text-muted)] mr-2">
                  <span className="text-blue-400">
                    {layer.input_types.join(", ")}
                  </span>
                  {" → "}
                  <span className="text-green-400">
                    {layer.output_types.join(", ")}
                  </span>
                </div>
                <button
                  onClick={() => handleEdit(layer)}
                  className="p-1.5 text-[var(--text-muted)] hover:text-[var(--text-primary)] hover:bg-[var(--bg-hover)] rounded transition-colors"
                >
                  Edit
                </button>
                <button
                  onClick={() => handleDelete(layer.name)}
                  className="p-1.5 text-[var(--text-muted)] hover:text-red-400 hover:bg-[var(--bg-hover)] rounded transition-colors"
                >
                  <Trash2 size={14} />
                </button>
              </div>
            </div>
          </div>
        ))}
        {layers.length === 0 && (
          <div className="text-center py-12 text-sm text-[var(--text-muted)]">
            No layers configured. Click "Add Layer" to create one.
          </div>
        )}
      </div>
    </div>
  );
}
