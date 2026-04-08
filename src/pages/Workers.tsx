import { useEffect, useState } from "react";
import { useAppStore } from "../stores/appStore";
import { Plus, Trash2, Save, Cpu } from "lucide-react";
import type { WorkerDefinition } from "../types";
import { PageHeader } from "@/components/app/PageHeader";
import { EmptyState } from "@/components/app/EmptyState";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { Textarea } from "@/components/ui/textarea";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { cn } from "@/lib/utils";

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
      <PageHeader
        icon={Cpu}
        title="Workers"
        description="Configure AI worker agents for each layer"
        action={
          <Button size="sm" onClick={handleNew}>
            <Plus size={14} />
            Add Worker
          </Button>
        }
      />

      {editing && (
        <Card>
          <CardContent className="p-4 space-y-4">
            <h3 className="text-sm font-medium text-foreground">
              {isNew ? "New Worker" : `Edit: ${editing.name}`}
            </h3>
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
              <div>
                <Label className="mb-1 block">Name</Label>
                <Input
                  value={editing.name}
                  onChange={(e) => setEditing({ ...editing, name: e.target.value })}
                  disabled={!isNew}
                />
              </div>
              <div>
                <Label className="mb-1 block">Layer</Label>
                <Select
                  value={editing.layer_name}
                  onValueChange={(v) => setEditing({ ...editing, layer_name: v })}
                >
                  <SelectTrigger>
                    <SelectValue placeholder="Select layer..." />
                  </SelectTrigger>
                  <SelectContent>
                    {layers.map((l) => (
                      <SelectItem key={l.name} value={l.name}>{l.name}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div>
                <Label className="mb-1 block">Model Override (optional)</Label>
                <Input
                  value={editing.model}
                  onChange={(e) => setEditing({ ...editing, model: e.target.value })}
                  placeholder="gpt-4o"
                />
              </div>
              <div>
                <Label className="mb-1 block">Temperature</Label>
                <Input
                  type="number"
                  step="0.1"
                  min="0"
                  max="2"
                  value={editing.temperature}
                  onChange={(e) =>
                    setEditing({ ...editing, temperature: parseFloat(e.target.value) || 0 })
                  }
                />
              </div>
              <div>
                <Label className="mb-1 block">Max Tokens</Label>
                <Input
                  type="number"
                  value={editing.max_tokens}
                  onChange={(e) =>
                    setEditing({ ...editing, max_tokens: parseInt(e.target.value) || 0 })
                  }
                />
              </div>
              <div className="flex items-end">
                <div className="flex items-center gap-2">
                  <Switch
                    checked={editing.enabled}
                    onCheckedChange={(checked) => setEditing({ ...editing, enabled: checked })}
                  />
                  <Label>Enabled</Label>
                </div>
              </div>
            </div>
            <div>
              <Label className="mb-1 block">System Prompt</Label>
              <Textarea
                value={editing.system_prompt}
                onChange={(e) => setEditing({ ...editing, system_prompt: e.target.value })}
                rows={4}
                className="font-mono resize-y"
                placeholder="You are an expert AI assistant..."
              />
            </div>
            <div className="flex items-center gap-2 justify-end">
              <Button variant="ghost" size="sm" onClick={() => setEditing(null)}>
                Cancel
              </Button>
              <Button size="sm" disabled={!editing.name || !editing.layer_name} onClick={handleSave}>
                <Save size={14} />
                Save
              </Button>
            </div>
          </CardContent>
        </Card>
      )}

      <div className="space-y-2">
        {workers.map((worker) => (
          <Card key={worker.name}>
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <div
                    className={cn(
                      "w-2 h-2 rounded-full",
                      worker.enabled ? "bg-success" : "bg-muted-foreground"
                    )}
                  />
                  <div>
                    <h4 className="text-sm font-medium text-foreground">{worker.name}</h4>
                    <div className="text-xs text-muted-foreground mt-0.5">
                      Layer: {worker.layer_name}
                      {worker.model && ` | Model: ${worker.model}`}
                      {" | "}
                      Temp: {worker.temperature ?? "default"}, Tokens:{" "}
                      {worker.max_tokens ?? "default"}
                    </div>
                  </div>
                </div>
                <div className="flex items-center gap-1">
                  <Button variant="ghost" size="sm" onClick={() => handleEdit(worker)}>
                    Edit
                  </Button>
                  <Button variant="ghost" size="icon" className="text-error hover:text-error" onClick={() => handleDelete(worker.name)} aria-label="Delete worker">
                    <Trash2 size={14} />
                  </Button>
                </div>
              </div>
              <div className="mt-2 px-5 text-xs text-muted-foreground font-mono line-clamp-2 bg-secondary rounded p-2">
                {worker.system_prompt}
              </div>
            </CardContent>
          </Card>
        ))}
        {workers.length === 0 && (
          <EmptyState
            icon={Cpu}
            title="No workers yet"
            description="Add a worker to start processing tasks"
            action={
              <Button size="sm" onClick={handleNew}>
                <Plus size={14} />
                Add Worker
              </Button>
            }
          />
        )}
      </div>
    </div>
  );
}
