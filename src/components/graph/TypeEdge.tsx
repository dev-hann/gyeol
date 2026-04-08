import { memo } from "react";
import {
  BaseEdge,
  EdgeLabelRenderer,
  getBezierPath,
  type EdgeProps,
} from "@xyflow/react";

function TypeEdgeComponent({
  id,
  sourceX,
  sourceY,
  targetX,
  targetY,
  sourcePosition,
  targetPosition,
  label,
  animated,
}: EdgeProps) {
  const [edgePath, labelX, labelY] = getBezierPath({
    sourceX,
    sourceY,
    targetX,
    targetY,
    sourcePosition,
    targetPosition,
  });

  return (
    <>
      <BaseEdge
        id={id}
        path={edgePath}
        className={animated ? "animated" : ""}
        style={{
          stroke: animated ? "var(--primary)" : "var(--border)",
          strokeWidth: animated ? 2 : 1,
        }}
      />
      {label && (
        <EdgeLabelRenderer>
          <div
            className="absolute pointer-events-auto rounded bg-card border border-border px-1.5 py-0.5 text-[10px] text-muted-foreground"
            style={{
              transform: `translate(-50%, -50%) translate(${labelX}px,${labelY}px)`,
            }}
          >
            {label}
          </div>
        </EdgeLabelRenderer>
      )}
    </>
  );
}

export const TypeEdge = memo(TypeEdgeComponent);
