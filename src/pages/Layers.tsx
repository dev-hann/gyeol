import { useCallback } from "react";
import { PageHeader } from "@/components/app/PageHeader";
import { EmptyState } from "@/components/app/EmptyState";
import { Button } from "@/components/ui/button";
import { Layers, Plus } from "lucide-react";
import { useAppStore } from "@/stores/appStore";
import { FlowCanvas } from "@/components/graph/FlowCanvas";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
} from "@/components/ui/sheet";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { useState } from "react";

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
  const { layers, saveLayer, fetchLayers } = useAppStore();
  const [addOpen, setAddOpen] = useState(false);
  const [form, setForm] = useState<LayerFormData>({ ...emptyForm });

  const handleAdd = useCallback(async () => {
    if (!form.name) return;
    await saveLayer({
      name: form.name,
      input_types: form.input_types.split(",").map((s) => s.trim()).filter(Boolean),
      output_types: form.output_types.split(",").map((s) => s.trim()).filter(Boolean),
      worker_names: form.worker_names.split(",").map((s) => s.trim()).filter(Boolean),
      order: form.order,
      enabled: form.enabled,
    });
    setForm({ ...emptyForm });
    setAddOpen(false);
    fetchLayers();
  }, [form, saveLayer, fetchLayers]);

  return (
    <div className="h-full flex flex-col">
      <div className="p-6 pb-0">
        <PageHeader
          icon={Layers}
          title="Layers"
          description="Visual workflow editor — drag to rearrange, click nodes for details, connect edges to link layers"
          action={
            <Button size="sm" onClick={() => setAddOpen(true)}>
              <Plus size={14} />
              Add Layer
            </Button>
          }
        />
      </div>

      <div className="flex-1 min-h-0 px-2 pb-2 pt-2">
        {layers.length > 0 ? (
          <FlowCanvas />
        ) : (
          <div className="h-full flex items-center justify-center">
            <EmptyState
              icon={Layers}
              title="No layers yet"
              description="Create your first layer to start building the workflow graph"
              action={
                <Button size="sm" onClick={() => setAddOpen(true)}>
                  <Plus size={14} />
                  Add Layer
                </Button>
              }
            />
          </div>
        )}
      </div>

      <Sheet open={addOpen} onOpenChange={setAddOpen}>
        <SheetContent side="right" className="w-[380px] sm:max-w-[380px]">
          <SheetHeader>
            <SheetTitle>New Layer</SheetTitle>
            <SheetDescription>Add a new processing layer to your workflow</SheetDescription>
          </SheetHeader>
          <div className="p-6 space-y-4">
            <div>
              <Label className="mb-1 block">Name</Label>
              <Input
                value={form.name}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
                placeholder="Layer name"
              />
            </div>
            <div>
              <Label className="mb-1 block">Input Types (comma-separated)</Label>
              <Input
                value={form.input_types}
                onChange={(e) => setForm({ ...form, input_types: e.target.value })}
                placeholder="issue, question"
              />
            </div>
            <div>
              <Label className="mb-1 block">Output Types (comma-separated)</Label>
              <Input
                value={form.output_types}
                onChange={(e) => setForm({ ...form, output_types: e.target.value })}
                placeholder="plan, analysis"
              />
            </div>
            <div>
              <Label className="mb-1 block">Worker Names (comma-separated)</Label>
              <Input
                value={form.worker_names}
                onChange={(e) => setForm({ ...form, worker_names: e.target.value })}
                placeholder="analyzer, planner"
              />
            </div>
            <div>
              <Label className="mb-1 block">Order</Label>
              <Input
                type="number"
                value={form.order}
                onChange={(e) => setForm({ ...form, order: parseInt(e.target.value) || 0 })}
              />
            </div>
            <div className="flex items-center gap-2">
              <Switch
                checked={form.enabled}
                onCheckedChange={(checked) => setForm({ ...form, enabled: checked })}
              />
              <Label>Enabled</Label>
            </div>
            <div className="flex gap-2 pt-2">
              <Button variant="ghost" className="flex-1" onClick={() => setAddOpen(false)}>
                Cancel
              </Button>
              <Button className="flex-1" disabled={!form.name} onClick={handleAdd}>
                Create Layer
              </Button>
            </div>
          </div>
        </SheetContent>
      </Sheet>
    </div>
  );
}
