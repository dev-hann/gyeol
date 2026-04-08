import { useEffect, useState } from "react";
import { useAppStore } from "@/stores/appStore";
import { Save, RotateCcw, Code2 } from "lucide-react";
import { PageHeader } from "@/components/app/PageHeader";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Textarea } from "@/components/ui/textarea";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

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
      <PageHeader
        icon={Code2}
        title="Prompt Editor"
        description="Edit system prompts for your AI workers"
      />

      <div className="flex items-center gap-3">
        <Select value={selectedWorker} onValueChange={setSelectedWorker}>
          <SelectTrigger className="w-[240px]">
            <SelectValue placeholder="Select a worker..." />
          </SelectTrigger>
          <SelectContent>
            {workers.map((w) => (
              <SelectItem key={w.name} value={w.name}>
                {w.name} ({w.layer_name})
              </SelectItem>
            ))}
          </SelectContent>
        </Select>

        {selectedWorker && (
          <div className="flex items-center gap-2">
            <Button size="sm" disabled={!hasChanges()} onClick={handleSave}>
              <Save size={14} />
              Save
            </Button>
            <Button variant="ghost" size="sm" disabled={!hasChanges()} onClick={handleReset}>
              <RotateCcw size={14} />
              Reset
            </Button>
            {hasChanges() && (
              <Badge variant="warning">Unsaved changes</Badge>
            )}
          </div>
        )}
      </div>

      {selectedWorker ? (
        <div className="flex-1 min-h-0">
          <Textarea
            value={prompt}
            onChange={(e) =>
              setLocalEdits((prev) => ({ ...prev, [selectedWorker]: e.target.value }))
            }
            className="w-full h-full min-h-[400px] font-mono resize-none"
            placeholder="Enter system prompt..."
          />
        </div>
      ) : (
        <div className="flex-1 flex items-center justify-center text-sm text-muted-foreground">
          Select a worker to edit its prompt
        </div>
      )}
    </div>
  );
}
