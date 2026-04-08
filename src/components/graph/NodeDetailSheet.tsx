import { useState } from "react";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
} from "@/components/ui/sheet";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { Separator } from "@/components/ui/separator";
import { Badge } from "@/components/ui/badge";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Trash2, Save, Cpu } from "lucide-react";
import { cn } from "@/lib/utils";
import type { LayerDefinition, WorkerDefinition } from "@/types";

interface NodeDetailSheetProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  layer: LayerDefinition | null;
  workers: WorkerDefinition[];
  onDelete: (name: string) => Promise<void>;
  onSave: (layer: Omit<LayerDefinition, "order" | "enabled"> & { order?: number; enabled?: boolean }) => Promise<void>;
}

export function NodeDetailSheet({
  open,
  onOpenChange,
  layer,
  workers,
  onDelete,
  onSave,
}: NodeDetailSheetProps) {
  const [editing, setEditing] = useState(false);
  const [form, setForm] = useState<{
    input_types: string;
    output_types: string;
    order: number;
    enabled: boolean;
  } | null>(null);

  if (!layer) return null;

  const current = form ?? {
    input_types: layer.input_types.join(", "),
    output_types: layer.output_types.join(", "),
    order: layer.order,
    enabled: layer.enabled,
  };

  const handleSave = async () => {
    await onSave({
      name: layer.name,
      input_types: current.input_types.split(",").map((s) => s.trim()).filter(Boolean),
      output_types: current.output_types.split(",").map((s) => s.trim()).filter(Boolean),
      worker_names: layer.worker_names,
      order: current.order,
      enabled: current.enabled,
    });
    setEditing(false);
    setForm(null);
  };

  return (
    <Sheet open={open} onOpenChange={(o) => { onOpenChange(o); if (!o) { setEditing(false); setForm(null); } }}>
      <SheetContent side="right" className="w-[380px] sm:max-w-[380px] p-0">
        <SheetHeader className="p-6 pb-4">
          <div className="flex items-center gap-2">
            <div className={cn("w-2.5 h-2.5 rounded-full", layer.enabled ? "bg-success" : "bg-muted-foreground")} />
            <SheetTitle>{layer.name}</SheetTitle>
          </div>
          <SheetDescription>Layer configuration and connected workers</SheetDescription>
        </SheetHeader>

        <Separator />

        <ScrollArea className="h-[calc(100vh-12rem)]">
          <div className="p-6 space-y-6">
            {!editing ? (
              <>
                <div className="space-y-3">
                  <div>
                    <Label>Input Types</Label>
                    <div className="flex gap-1 mt-1 flex-wrap">
                      {layer.input_types.length > 0 ? (
                        layer.input_types.map((t) => <Badge key={t} variant="info">{t}</Badge>)
                      ) : (
                        <span className="text-xs text-muted-foreground">None</span>
                      )}
                    </div>
                  </div>
                  <div>
                    <Label>Output Types</Label>
                    <div className="flex gap-1 mt-1 flex-wrap">
                      {layer.output_types.length > 0 ? (
                        layer.output_types.map((t) => <Badge key={t} variant="success">{t}</Badge>)
                      ) : (
                        <span className="text-xs text-muted-foreground">None</span>
                      )}
                    </div>
                  </div>
                  <div className="flex items-center justify-between">
                    <Label>Enabled</Label>
                    <Badge variant={layer.enabled ? "success" : "secondary"}>
                      {layer.enabled ? "Active" : "Disabled"}
                    </Badge>
                  </div>
                  <div className="flex items-center justify-between">
                    <Label>Order</Label>
                    <span className="text-sm text-foreground">{layer.order}</span>
                  </div>
                </div>

                <div className="flex gap-2">
                  <Button
                    variant="outline"
                    size="sm"
                    className="flex-1"
                    onClick={() => setEditing(true)}
                  >
                    Edit
                  </Button>
                  <Button
                    variant="destructive"
                    size="icon"
                    onClick={() => onDelete(layer.name)}
                    aria-label="Delete layer"
                  >
                    <Trash2 size={14} />
                  </Button>
                </div>
              </>
            ) : (
              <div className="space-y-4">
                <div>
                  <Label htmlFor="edit-input-types" className="mb-1 block">Input Types (comma-separated)</Label>
                  <Input
                    id="edit-input-types"
                    value={current.input_types}
                    onChange={(e) => setForm({ ...current, input_types: e.target.value })}
                    placeholder="issue, question"
                  />
                </div>
                <div>
                  <Label htmlFor="edit-output-types" className="mb-1 block">Output Types (comma-separated)</Label>
                  <Input
                    id="edit-output-types"
                    value={current.output_types}
                    onChange={(e) => setForm({ ...current, output_types: e.target.value })}
                    placeholder="plan, analysis"
                  />
                </div>
                <div>
                  <Label htmlFor="edit-order" className="mb-1 block">Order</Label>
                  <Input
                    id="edit-order"
                    type="number"
                    value={current.order}
                    onChange={(e) => setForm({ ...current, order: parseInt(e.target.value) || 0 })}
                  />
                </div>
                <div className="flex items-center gap-2">
                  <Switch
                    id="edit-enabled"
                    checked={current.enabled}
                    onCheckedChange={(checked) => setForm({ ...current, enabled: checked })}
                  />
                  <Label htmlFor="edit-enabled">Enabled</Label>
                </div>
                <div className="flex gap-2">
                  <Button variant="ghost" size="sm" className="flex-1" onClick={() => { setEditing(false); setForm(null); }}>
                    Cancel
                  </Button>
                  <Button size="sm" className="flex-1" onClick={handleSave}>
                    <Save size={14} />
                    Save
                  </Button>
                </div>
              </div>
            )}

            <Separator />

            <div>
              <div className="flex items-center justify-between mb-3">
                <h4 className="text-sm font-medium text-foreground flex items-center gap-1.5">
                  <Cpu size={14} />
                  Workers ({workers.length})
                </h4>
              </div>
              {workers.length > 0 ? (
                <div className="space-y-2">
                  {workers.map((w) => (
                    <div key={w.name} className="rounded-md border border-border bg-secondary p-3 space-y-1">
                      <div className="flex items-center justify-between">
                        <span className="text-sm font-medium text-foreground">{w.name}</span>
                        <Badge variant={w.enabled ? "success" : "secondary"}>
                          {w.enabled ? "Active" : "Disabled"}
                        </Badge>
                      </div>
                      {w.model && (
                        <div className="text-xs text-muted-foreground">Model: {w.model}</div>
                      )}
                      <div className="text-xs text-muted-foreground font-mono line-clamp-2 bg-background rounded p-1.5">
                        {w.system_prompt}
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="text-xs text-muted-foreground text-center py-4">
                  No workers assigned to this layer
                </div>
              )}
            </div>
          </div>
        </ScrollArea>
      </SheetContent>
    </Sheet>
  );
}
