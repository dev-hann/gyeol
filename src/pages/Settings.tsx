import { useEffect, useMemo, useState } from "react";
import { useAppStore } from "@/stores/appStore";
import { Save, Settings } from "lucide-react";
import type { ProviderSettings } from "@/types";
import { PageHeader } from "@/components/app/PageHeader";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent } from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Skeleton } from "@/components/ui/skeleton";

export function SettingsPage() {
  const { settings, fetchSettings, saveSettings } = useAppStore();
  const [form, setForm] = useState<ProviderSettings | null>(null);

  useEffect(() => {
    fetchSettings();
  }, [fetchSettings]);

  const currentForm = useMemo(() => form ?? settings, [form, settings]);

  if (!currentForm) {
    return (
      <div className="p-6 space-y-6 max-w-2xl">
        <PageHeader
          icon={Settings}
          title="Settings"
          description="Configure AI provider and system settings"
        />
        <Card>
          <CardContent className="p-4 space-y-4">
            <Skeleton className="h-4 w-32" />
            <Skeleton className="h-9 w-full" />
            <Skeleton className="h-4 w-24" />
            <div className="grid grid-cols-2 gap-4">
              <Skeleton className="h-9" />
              <Skeleton className="h-9" />
            </div>
          </CardContent>
        </Card>
      </div>
    );
  }

  const handleSave = () => {
    saveSettings(currentForm);
    setForm(null);
  };

  return (
    <div className="p-6 space-y-6 max-w-2xl">
      <PageHeader
        icon={Settings}
        title="Settings"
        description="Configure AI provider and system settings"
        action={
          <Button size="sm" onClick={handleSave}>
            <Save size={14} />
            Save Settings
          </Button>
        }
      />

      <Card>
        <CardContent className="p-4 space-y-4">
          <h3 className="text-sm font-medium text-foreground pb-2 border-b border-border">
            AI Provider
          </h3>
          <div>
            <Label className="mb-1 block">Active Provider</Label>
            <Select
              value={currentForm.provider}
              onValueChange={(v) =>
                setForm({ ...currentForm, provider: v as ProviderSettings["provider"] })
              }
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="OpenAI">OpenAI</SelectItem>
                <SelectItem value="Anthropic">Anthropic</SelectItem>
                <SelectItem value="Ollama">Ollama (Local)</SelectItem>
              </SelectContent>
            </Select>
          </div>

          <Separator />

          <h3 className="text-sm font-medium text-foreground pb-2 border-b border-border">
            OpenAI
          </h3>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <Label className="mb-1 block">API Key</Label>
              <Input
                type="password"
                value={currentForm.openai_api_key}
                onChange={(e) => setForm({ ...currentForm, openai_api_key: e.target.value })}
              />
            </div>
            <div>
              <Label className="mb-1 block">Model</Label>
              <Input
                value={currentForm.openai_model}
                onChange={(e) => setForm({ ...currentForm, openai_model: e.target.value })}
              />
            </div>
          </div>

          <Separator />

          <h3 className="text-sm font-medium text-foreground pb-2 border-b border-border">
            Anthropic
          </h3>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <Label className="mb-1 block">API Key</Label>
              <Input
                type="password"
                value={currentForm.anthropic_api_key}
                onChange={(e) => setForm({ ...currentForm, anthropic_api_key: e.target.value })}
              />
            </div>
            <div>
              <Label className="mb-1 block">Model</Label>
              <Input
                value={currentForm.anthropic_model}
                onChange={(e) => setForm({ ...currentForm, anthropic_model: e.target.value })}
              />
            </div>
          </div>

          <Separator />

          <h3 className="text-sm font-medium text-foreground pb-2 border-b border-border">
            Ollama (Local)
          </h3>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <Label className="mb-1 block">Base URL</Label>
              <Input
                value={currentForm.ollama_base_url}
                onChange={(e) => setForm({ ...currentForm, ollama_base_url: e.target.value })}
              />
            </div>
            <div>
              <Label className="mb-1 block">Model</Label>
              <Input
                value={currentForm.ollama_model}
                onChange={(e) => setForm({ ...currentForm, ollama_model: e.target.value })}
              />
            </div>
          </div>

          <Separator />

          <h3 className="text-sm font-medium text-foreground pb-2 border-b border-border">
            Defaults
          </h3>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <Label className="mb-1 block">Default Temperature</Label>
              <Input
                type="number"
                step="0.1"
                min="0"
                max="2"
                value={currentForm.default_temperature}
                onChange={(e) =>
                  setForm({ ...currentForm, default_temperature: parseFloat(e.target.value) || 0 })
                }
              />
            </div>
            <div>
              <Label className="mb-1 block">Default Max Tokens</Label>
              <Input
                type="number"
                value={currentForm.default_max_tokens}
                onChange={(e) =>
                  setForm({ ...currentForm, default_max_tokens: parseInt(e.target.value) || 0 })
                }
              />
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
