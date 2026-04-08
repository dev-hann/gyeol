import { memo } from "react";
import { Handle, Position, type NodeProps, type Node } from "@xyflow/react";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";
import { Cpu, Loader2 } from "lucide-react";
import type { LayerNodeData } from "./graph-utils";

function LayerNodeComponent({ data, selected }: NodeProps<Node<LayerNodeData>>) {
  return (
    <>
      <Handle
        type="target"
        position={Position.Left}
      />
      <Card
        tabIndex={0}
        role="button"
        aria-label={`${data.name} layer${data.enabled ? "" : " (disabled)"}`}
        className={cn(
          "w-[240px] p-3 transition-all cursor-pointer hover:shadow-md",
          data.enabled ? "border-border" : "border-border opacity-50",
          selected && "ring-2 ring-ring",
          "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring",
          data.runningTasks > 0 && "node-running"
        )}
      >
        <div className="flex items-center justify-between mb-2">
          <div className="flex items-center gap-2">
            <div
              className={cn(
                "w-2 h-2 rounded-full",
                data.enabled ? "bg-success" : "bg-muted-foreground"
              )}
            />
            <span className="text-sm font-medium text-foreground truncate">
              {data.name}
            </span>
          </div>
          {data.runningTasks > 0 && (
            <Badge variant="info" className="flex items-center gap-1">
              <Loader2 size={10} className="animate-spin" />
              {data.runningTasks}
            </Badge>
          )}
        </div>

        {data.workerNames.length > 0 && (
          <div className="flex items-center gap-1 mb-2 text-xs text-muted-foreground">
            <Cpu size={12} />
            <span className="truncate">{data.workerNames.join(", ")}</span>
          </div>
        )}

        <div className="flex items-center gap-1 flex-wrap">
          {data.outputTypes.map((t) => (
            <Badge key={t} variant="secondary" className="px-1 py-0">
              {t}
            </Badge>
          ))}
        </div>
      </Card>
      <Handle
        type="source"
        position={Position.Right}
      />
    </>
  );
}

export const LayerNode = memo(LayerNodeComponent);
