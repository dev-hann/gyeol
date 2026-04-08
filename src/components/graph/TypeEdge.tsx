import { memo } from "react";
import {
  BaseEdge,
  EdgeLabelRenderer,
  getBezierPath,
  type EdgeProps,
} from "@xyflow/react";

const labelClassName =
  "absolute pointer-events-auto rounded bg-card border border-border px-1.5 py-0.5 text-[10px] text-muted-foreground";
const labelStyle = (x: number, y: number): React.CSSProperties => ({
  transform: `translate(-50%, -50%) translate(${x}px,${y}px)`,
});

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
      />
      {label && (
        <EdgeLabelRenderer>
          <div
            className={labelClassName}
            style={labelStyle(labelX, labelY)}
          >
            {label}
          </div>
        </EdgeLabelRenderer>
      )}
    </>
  );
}

export const TypeEdge = memo(TypeEdgeComponent);
