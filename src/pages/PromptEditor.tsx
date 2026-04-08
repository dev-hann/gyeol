import { useEffect, useState } from "react";
import { useAppStore } from "../stores/appStore";
import { Save, RotateCcw } from "lucide-react";

export function PromptEditorPage() {
  const { workers, fetchWorkers, saveWorker } = useAppStore();
  const [selectedWorker, setSelectedWorker] = useState<string>("");
  const [localEdits, setLocalEdits] = useState<Record<string, string>>({});

  useEffect(() => {
    fetchWorkers();
  }, [fetchWorkers]);

  const worker = workers.find((w) => w.name === selectedWorker);
  const prompt = selectedWorker in localEdits
    ? localEdits[selectedWorker]
    : (worker?.system_prompt ?? "");

  const handleSave = async () => {
    if (!worker) return;
    await saveWorker({
      ...worker,
      system_prompt: prompt,
    });
  };

  const handleReset = () => {
    setLocalEdits((prev) => {
      const next = { ...prev };
      delete next[selectedWorker];
      return next;
    });
  };

  const hasChanges = () => {
    return worker && prompt !== worker.system_prompt;
  };

  return (
    <div className="p-6 space-y-6 h-full flex flex-col">
      <div>
        <h2 className="text-xl font-semibold">Prompt Editor</h2>
        <p className="text-sm text-[var(--text-muted)] mt-1">
          Edit system prompts for your AI workers
        </p>
      </div>

      <div className="flex items-center gap-3">
        <select
          value={selectedWorker}
          onChange={(e) => setSelectedWorker(e.target.value)}
          className="px-3 py-1.5 bg-[var(--bg-tertiary)] border border-[var(--border)] rounded-md text-sm text-[var(--text-primary)]"
        >
          <option value="">Select a worker...</option>
          {workers.map((w) => (
            <option key={w.name} value={w.name}>
              {w.name} ({w.layer_name})
            </option>
          ))}
        </select>

        {selectedWorker && (
          <div className="flex items-center gap-2">
            <button
              onClick={handleSave}
              disabled={!hasChanges()}
              className="flex items-center gap-1.5 px-3 py-1.5 bg-[var(--accent)] hover:bg-[var(--accent-hover)] text-white text-sm rounded-md transition-colors disabled:opacity-50"
            >
              <Save size={14} />
              Save
            </button>
            <button
              onClick={handleReset}
              disabled={!hasChanges()}
              className="flex items-center gap-1.5 px-3 py-1.5 bg-[var(--bg-hover)] text-[var(--text-secondary)] hover:text-[var(--text-primary)] text-sm rounded-md transition-colors disabled:opacity-50"
            >
              <RotateCcw size={14} />
              Reset
            </button>
            {hasChanges() && (
              <span className="text-xs text-yellow-400">Unsaved changes</span>
            )}
          </div>
        )}
      </div>

      {selectedWorker ? (
        <div className="flex-1 min-h-0">
          <textarea
            value={prompt}
            onChange={(e) =>
              setLocalEdits((prev) => ({ ...prev, [selectedWorker]: e.target.value }))
            }
            className="w-full h-full min-h-[400px] px-4 py-3 bg-[var(--bg-secondary)] border border-[var(--border)] rounded-lg text-sm text-[var(--text-primary)] font-mono resize-none focus:outline-none focus:border-[var(--accent)]"
            placeholder="Enter system prompt..."
          />
        </div>
      ) : (
        <div className="flex-1 flex items-center justify-center text-sm text-[var(--text-muted)]">
          Select a worker to edit its prompt
        </div>
      )}
    </div>
  );
}
