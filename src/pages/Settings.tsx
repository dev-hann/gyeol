import { useEffect, useMemo, useState } from "react";
import { useAppStore } from "../stores/appStore";
import { Save } from "lucide-react";
import type { ProviderSettings } from "../types";

export function SettingsPage() {
  const { settings, fetchSettings, saveSettings } = useAppStore();
  const [form, setForm] = useState<ProviderSettings | null>(null);

  useEffect(() => {
    fetchSettings();
  }, [fetchSettings]);

  const currentForm = useMemo(() => form ?? settings, [form, settings]);

  if (!currentForm) {
    return (
      <div className="p-6">
        <div className="text-sm text-[var(--text-muted)]">Loading...</div>
      </div>
    );
  }

  const handleSave = () => {
    saveSettings(currentForm);
    setForm(null);
  };

  return (
    <div className="p-6 space-y-6 max-w-2xl">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-xl font-semibold">Settings</h2>
          <p className="text-sm text-[var(--text-muted)] mt-1">
            Configure AI provider and system settings
          </p>
        </div>
        <button
          onClick={handleSave}
          className="flex items-center gap-1.5 px-3 py-1.5 bg-[var(--accent)] hover:bg-[var(--accent-hover)] text-white text-sm rounded-md transition-colors"
        >
          <Save size={14} />
          Save Settings
        </button>
      </div>

      <div className="bg-[var(--bg-secondary)] border border-[var(--border)] rounded-lg p-4 space-y-4">
        <h3 className="text-sm font-medium border-b border-[var(--border)] pb-2">
          AI Provider
        </h3>
        <div>
          <label className="block text-xs text-[var(--text-muted)] mb-1">
            Active Provider
          </label>
          <select
            value={currentForm.provider}
            onChange={(e) =>
              setForm({
                ...currentForm,
                provider: e.target.value as ProviderSettings["provider"],
              })
            }
            className="w-full px-3 py-1.5 bg-[var(--bg-tertiary)] border border-[var(--border)] rounded-md text-sm text-[var(--text-primary)]"
          >
            <option value="OpenAI">OpenAI</option>
            <option value="Anthropic">Anthropic</option>
            <option value="Ollama">Ollama (Local)</option>
          </select>
        </div>

        <div className="space-y-4">
          <h3 className="text-sm font-medium border-b border-[var(--border)] pb-2">
            OpenAI
          </h3>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-xs text-[var(--text-muted)] mb-1">
                API Key
              </label>
              <input
                type="password"
                value={currentForm.openai_api_key}
                onChange={(e) =>
                  setForm({ ...currentForm, openai_api_key: e.target.value })
                }
                className="w-full px-3 py-1.5 bg-[var(--bg-tertiary)] border border-[var(--border)] rounded-md text-sm text-[var(--text-primary)]"
              />
            </div>
            <div>
              <label className="block text-xs text-[var(--text-muted)] mb-1">
                Model
              </label>
              <input
                value={currentForm.openai_model}
                onChange={(e) =>
                  setForm({ ...currentForm, openai_model: e.target.value })
                }
                className="w-full px-3 py-1.5 bg-[var(--bg-tertiary)] border border-[var(--border)] rounded-md text-sm text-[var(--text-primary)]"
              />
            </div>
          </div>
        </div>

        <div className="space-y-4">
          <h3 className="text-sm font-medium border-b border-[var(--border)] pb-2">
            Anthropic
          </h3>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-xs text-[var(--text-muted)] mb-1">
                API Key
              </label>
              <input
                type="password"
                value={currentForm.anthropic_api_key}
                onChange={(e) =>
                  setForm({ ...currentForm, anthropic_api_key: e.target.value })
                }
                className="w-full px-3 py-1.5 bg-[var(--bg-tertiary)] border border-[var(--border)] rounded-md text-sm text-[var(--text-primary)]"
              />
            </div>
            <div>
              <label className="block text-xs text-[var(--text-muted)] mb-1">
                Model
              </label>
              <input
                value={currentForm.anthropic_model}
                onChange={(e) =>
                  setForm({ ...currentForm, anthropic_model: e.target.value })
                }
                className="w-full px-3 py-1.5 bg-[var(--bg-tertiary)] border border-[var(--border)] rounded-md text-sm text-[var(--text-primary)]"
              />
            </div>
          </div>
        </div>

        <div className="space-y-4">
          <h3 className="text-sm font-medium border-b border-[var(--border)] pb-2">
            Ollama (Local)
          </h3>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-xs text-[var(--text-muted)] mb-1">
                Base URL
              </label>
              <input
                value={currentForm.ollama_base_url}
                onChange={(e) =>
                  setForm({ ...currentForm, ollama_base_url: e.target.value })
                }
                className="w-full px-3 py-1.5 bg-[var(--bg-tertiary)] border border-[var(--border)] rounded-md text-sm text-[var(--text-primary)]"
              />
            </div>
            <div>
              <label className="block text-xs text-[var(--text-muted)] mb-1">
                Model
              </label>
              <input
                value={currentForm.ollama_model}
                onChange={(e) =>
                  setForm({ ...currentForm, ollama_model: e.target.value })
                }
                className="w-full px-3 py-1.5 bg-[var(--bg-tertiary)] border border-[var(--border)] rounded-md text-sm text-[var(--text-primary)]"
              />
            </div>
          </div>
        </div>

        <div className="space-y-4">
          <h3 className="text-sm font-medium border-b border-[var(--border)] pb-2">
            Defaults
          </h3>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-xs text-[var(--text-muted)] mb-1">
                Default Temperature
              </label>
              <input
                type="number"
                step="0.1"
                min="0"
                max="2"
                value={currentForm.default_temperature}
                onChange={(e) =>
                  setForm({
                    ...currentForm,
                    default_temperature: parseFloat(e.target.value) || 0,
                  })
                }
                className="w-full px-3 py-1.5 bg-[var(--bg-tertiary)] border border-[var(--border)] rounded-md text-sm text-[var(--text-primary)]"
              />
            </div>
            <div>
              <label className="block text-xs text-[var(--text-muted)] mb-1">
                Default Max Tokens
              </label>
              <input
                type="number"
                value={currentForm.default_max_tokens}
                onChange={(e) =>
                  setForm({
                    ...currentForm,
                    default_max_tokens: parseInt(e.target.value) || 0,
                  })
                }
                className="w-full px-3 py-1.5 bg-[var(--bg-tertiary)] border border-[var(--border)] rounded-md text-sm text-[var(--text-primary)]"
              />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
