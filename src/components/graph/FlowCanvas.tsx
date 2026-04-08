import { useState, useCallback, useEffect } from "react";
import {
  ReactFlow,
  Background,
  Controls,
  MiniMap,
  addEdge,
  useNodesState,
  useEdgesState,
  type Connection,
  type NodeMouseHandler,
  BackgroundVariant,
} from "@xyflow/react";
import "@xyflow/react/dist/style.css";

import { useAppStore } from "@/stores/appStore";
import { layersToGraph, type LayerNodeData } from "./graph-utils";
import { LayerNode } from "./LayerNode";
import { TypeEdge } from "./TypeEdge";
import { NodeDetailSheet } from "./NodeDetailSheet";

const nodeTypes = { layerNode: LayerNode };
const edgeTypes = { typeEdge: TypeEdge };

const defaultEdgeOptions = {
  type: "typeEdge",
};

type NodeState = "default" | "disabled" | "running";

const minimapColors: Record<NodeState, { fill: string; stroke: string }> = {
  default: { fill: "var(--primary)", stroke: "var(--border)" },
  disabled: { fill: "var(--muted-foreground)", stroke: "var(--muted-foreground)" },
  running: { fill: "var(--info)", stroke: "var(--info)" },
};

const getNodeState = (data: unknown): NodeState => {
  const d = data as LayerNodeData | undefined;
  if (!d || d.enabled === undefined) return "default";
  if (!d.enabled) return "disabled";
  if (d.runningTasks > 0) return "running";
  return "default";
};

const panelBase = "!bg-card !border-border !rounded-md";
const controlClassName = `${panelBase} [&>button]:!bg-card [&>button]:!border-border [&>button]:!text-foreground [&>button:hover]:!bg-accent`;
const miniMapClassName = panelBase;

export function FlowCanvas() {
  const { layers, tasks, workers, fetchLayers, fetchTasks, fetchWorkers, saveLayer, deleteLayer } = useAppStore();
  const [nodes, setNodes, onNodesChange] = useNodesState([]);
  const [edges, setEdges, onEdgesChange] = useEdgesState([]);
  const [selectedLayer, setSelectedLayer] = useState<string | null>(null);
  const [sheetOpen, setSheetOpen] = useState(false);

  useEffect(() => {
    fetchLayers();
    fetchTasks();
    fetchWorkers();
    const interval = setInterval(() => {
      fetchTasks();
    }, 5000);
    return () => clearInterval(interval);
  }, [fetchLayers, fetchTasks, fetchWorkers]);

  useEffect(() => {
    const { nodes: newNodes, edges: newEdges } = layersToGraph(layers, tasks);
    setNodes(newNodes);
    setEdges(newEdges);
  }, [layers, tasks, setNodes, setEdges]);

  const onNodeClick: NodeMouseHandler = useCallback((_event, node) => {
    const d = node.data as { name: string };
    setSelectedLayer(d.name);
    setSheetOpen(true);
  }, []);

  const onConnect = useCallback(
    (connection: Connection) => {
      if (!connection.source || !connection.target) return;
      const sourceName = connection.source.replace("layer-", "");
      const targetName = connection.target.replace("layer-", "");
      const sourceLayer = layers.find((l) => l.name === sourceName);
      const targetLayer = layers.find((l) => l.name === targetName);
      if (!sourceLayer || !targetLayer) return;

      const newOutputTypes = [...new Set([...sourceLayer.output_types, ...targetLayer.input_types])];
      saveLayer({ ...sourceLayer, output_types: newOutputTypes });
      setEdges((eds) => addEdge({ ...connection, type: "typeEdge" }, eds));
    },
    [layers, saveLayer, setEdges]
  );

  const selectedLayerData = layers.find((l) => l.name === selectedLayer);
  const selectedWorkers = selectedLayerData
    ? workers.filter((w) => w.layer_name === selectedLayerData.name)
    : [];

  return (
    <div className="w-full h-full">
      <ReactFlow
        nodes={nodes}
        edges={edges}
        onNodesChange={onNodesChange}
        onEdgesChange={onEdgesChange}
        onNodeClick={onNodeClick}
        onConnect={onConnect}
        nodeTypes={nodeTypes}
        edgeTypes={edgeTypes}
        defaultEdgeOptions={defaultEdgeOptions}
        fitView
        fitViewOptions={{ padding: 0.3 }}
        proOptions={{ hideAttribution: true }}
        className="bg-background"
      >
        <Background variant={BackgroundVariant.Dots} gap={20} size={1} color="var(--border)" />
        <Controls
          className={controlClassName}
        />
        <MiniMap
          className={miniMapClassName}
          nodeColor={(node) => minimapColors[getNodeState(node.data)].fill}
          nodeStrokeColor={(node) => minimapColors[getNodeState(node.data)].stroke}
          nodeBorderRadius={6}
          pannable
          zoomable
          maskColor="var(--minimap-mask)"
        />
      </ReactFlow>

      <NodeDetailSheet
        open={sheetOpen}
        onOpenChange={setSheetOpen}
        layer={selectedLayerData ?? null}
        workers={selectedWorkers}
        onDelete={async (name) => {
          await deleteLayer(name);
          setSheetOpen(false);
          setSelectedLayer(null);
        }}
        onSave={async (layer) => {
          await saveLayer(layer);
        }}
      />
    </div>
  );
}
