import { memo } from "react";
import {
  BaseEdge,
  EdgeLabelRenderer,
  getBezierPath,
  type EdgeProps,
} from "@xyflow/react";

const labelClassName =
  "absolute pointer-events-auto rounded bg-card border border-border px-1.5 py-0.5 text-2xs text-muted-foreground";

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
        className={animated ? "animated" : undefined}
      />
      {label && (
        <EdgeLabelRenderer>
          <div
            className={labelClassName}
            style={{ left: labelX, top: labelY, transform: "translate(-50%, -50%)" }}
          >
            {label}
          </div>
        </EdgeLabelRenderer>
      )}
    </>
  );
}

export const TypeEdge = memo(TypeEdgeComponent);
