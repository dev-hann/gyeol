import { memo } from "react";
import {
  BaseEdge,
  EdgeLabelRenderer,
  getBezierPath,
  type EdgeProps,
} from "@xyflow/react";

const labelClassName =
  "absolute pointer-events-auto rounded bg-card border border-border px-1.5 py-0.5 text-2xs text-muted-foreground";
const labelTransform = (x: number, y: number) =>
  `translate(-50%, -50%) translate(${x}px,${y}px)`;

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
            style={{ transform: labelTransform(labelX, labelY) }}
          >
            {label}
          </div>
        </EdgeLabelRenderer>
      )}
    </>
  );
}

export const TypeEdge = memo(TypeEdgeComponent);
