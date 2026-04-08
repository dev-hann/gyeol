import dagre from "dagre";
import type { Node, Edge } from "@xyflow/react";
import type { LayerDefinition, Task } from "@/types";

export interface LayerNodeData extends Record<string, unknown> {
  name: string;
  enabled: boolean;
  workerNames: string[];
  inputTypes: string[];
  outputTypes: string[];
  order: number;
  runningTasks: number;
}

const NODE_WIDTH = 240;
const NODE_HEIGHT = 120;

export function layersToGraph(
  layers: LayerDefinition[],
  tasks: Task[]
): { nodes: Node<LayerNodeData>[]; edges: Edge[] } {
  const g = new dagre.graphlib.Graph();
  g.setDefaultEdgeLabel(() => ({}));
  g.setGraph({ rankdir: "LR", nodesep: 60, ranksep: 120 });

  const runningCounts: Record<string, number> = {};
  for (const t of tasks) {
    if (t.status === "Running" && t.layer_name) {
      runningCounts[t.layer_name] = (runningCounts[t.layer_name] ?? 0) + 1;
    }
  }

  const nodes: Node<LayerNodeData>[] = layers.map((layer) => {
    const id = `layer-${layer.name}`;
    g.setNode(id, { width: NODE_WIDTH, height: NODE_HEIGHT });
    return {
      id,
      type: "layerNode",
      position: { x: 0, y: 0 },
      data: {
        name: layer.name,
        enabled: layer.enabled,
        workerNames: layer.worker_names,
        inputTypes: layer.input_types,
        outputTypes: layer.output_types,
        order: layer.order,
        runningTasks: runningCounts[layer.name] ?? 0,
      },
    };
  });

  const inputTypeSets = new Map(layers.map((l) => [l.name, new Set(l.input_types)]));

  const edges: Edge[] = [];
  for (let i = 0; i < layers.length; i++) {
    for (let j = 0; j < layers.length; j++) {
      if (i === j) continue;
      const source = layers[i];
      const target = layers[j];
      const targetInputs = inputTypeSets.get(target.name)!;
      const overlap = source.output_types.filter((t) => targetInputs.has(t));
      if (overlap.length > 0) {
        const id = `edge-${source.name}-${target.name}`;
        const isRunning = tasks.some(
          (t) =>
            t.status === "Running" &&
            (t.layer_name === source.name || t.layer_name === target.name)
        );
        g.setEdge(`layer-${source.name}`, `layer-${target.name}`, {});
        edges.push({
          id,
          source: `layer-${source.name}`,
          target: `layer-${target.name}`,
          label: overlap.join(", "),
          type: "typeEdge",
          animated: isRunning,
          data: { types: overlap },
        });
      }
    }
  }

  dagre.layout(g);

  for (const node of nodes) {
    const pos = g.node(node.id);
    if (pos) {
      node.position = { x: pos.x - NODE_WIDTH / 2, y: pos.y - NODE_HEIGHT / 2 };
    }
  }

  return { nodes, edges };
}
