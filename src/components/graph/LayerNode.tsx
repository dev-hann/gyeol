import { memo } from "react";
import { Handle, Position, type NodeProps } from "@xyflow/react";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";
import { Cpu, Loader2 } from "lucide-react";
import type { LayerNodeData } from "./graph-utils";

function LayerNodeComponent({ data, selected }: NodeProps) {
  const d = data as unknown as LayerNodeData;
  return (
    <>
      <Handle
        type="target"
        position={Position.Left}
        className="!w-3 !h-3 !bg-muted-foreground !border-2 !border-card"
      />
      <Card
        tabIndex={0}
        role="button"
        aria-label={`${d.name} layer${d.enabled ? "" : " (disabled)"}`}
        className={cn(
          "w-[240px] p-3 transition-all cursor-pointer hover:shadow-md",
          d.enabled ? "border-border" : "border-border opacity-50",
          selected && "ring-2 ring-ring",
          "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring",
          d.runningTasks > 0 && "node-running"
        )}
      >
        <div className="flex items-center justify-between mb-2">
          <div className="flex items-center gap-2">
            <div
              className={cn(
                "w-2 h-2 rounded-full",
                d.enabled ? "bg-success" : "bg-muted-foreground"
              )}
            />
            <span className="text-sm font-medium text-foreground truncate">
              {d.name}
            </span>
          </div>
          {d.runningTasks > 0 && (
            <Badge variant="info" className="flex items-center gap-1">
              <Loader2 size={10} className="animate-spin" />
              {d.runningTasks}
            </Badge>
          )}
        </div>

        {d.workerNames.length > 0 && (
          <div className="flex items-center gap-1 mb-2 text-xs text-muted-foreground">
            <Cpu size={12} />
            <span className="truncate">{d.workerNames.join(", ")}</span>
          </div>
        )}

        <div className="flex items-center gap-1 flex-wrap">
          {d.outputTypes.map((t) => (
            <Badge key={t} variant="secondary" className="px-1 py-0">
              {t}
            </Badge>
          ))}
        </div>
      </Card>
      <Handle
        type="source"
        position={Position.Right}
        className="!w-3 !h-3 !bg-primary !border-2 !border-card"
      />
    </>
  );
}

export const LayerNode = memo(LayerNodeComponent);
