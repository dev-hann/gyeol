import 'package:flutter/material.dart';
import 'package:gyeol/core/theme/app_theme.dart';
import 'package:gyeol/features/layers/graph/graph_utils.dart';
import 'package:gyeol/features/layers/graph/layer_node_widget.dart';
import 'package:vyuh_node_flow/vyuh_node_flow.dart';

class FlowCanvas extends StatelessWidget {
  const FlowCanvas({
    required this.controller,
    required this.onNodeTap,
    this.onNodeDragEnd,
    this.onConnectionCreated,
    this.onConnectionRemoved,
    this.onViewportChanged,
    super.key,
  });
  final NodeFlowController<LayerGraphData, void> controller;
  final void Function(String nodeId) onNodeTap;
  final VoidCallback? onNodeDragEnd;
  final void Function(String sourceNodeId, String targetNodeId)?
  onConnectionCreated;
  final void Function(String sourceNodeId, String targetNodeId)?
  onConnectionRemoved;
  final VoidCallback? onViewportChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: NodeFlowEditor<LayerGraphData, void>(
        controller: controller,
        theme: NodeFlowTheme(
          nodeTheme: NodeTheme.dark,
          connectionTheme: ConnectionTheme.dark.copyWith(
            style: ConnectionStyles.bezier,
            color: AppColors.primaryBright,
            selectedColor: AppColors.infoBright,
            strokeWidth: 3,
            selectedStrokeWidth: 3,
            bezierCurvature: 0.5,
            cornerRadius: 50,
          ),
          temporaryConnectionTheme: ConnectionTheme.dark.copyWith(
            style: ConnectionStyles.bezier,
          ),
          portTheme: PortTheme.dark.copyWith(size: const Size(16, 16)),
          labelTheme: LabelTheme.dark,
          gridTheme: GridTheme.dark.copyWith(color: AppColors.border),
          selectionTheme: SelectionTheme.dark,
          cursorTheme: CursorTheme.dark,
          resizerTheme: ResizerTheme.dark,
          backgroundColor: AppColors.background,
        ),
        events: NodeFlowEvents<LayerGraphData, void>(
          node: NodeEvents<LayerGraphData>(
            onDragStop: (_) => onNodeDragEnd?.call(),
          ),
          connection: ConnectionEvents<LayerGraphData, void>(
            onCreated: (conn) =>
                onConnectionCreated?.call(conn.sourceNodeId, conn.targetNodeId),
            onDeleted: (conn) =>
                onConnectionRemoved?.call(conn.sourceNodeId, conn.targetNodeId),
          ),
          viewport: ViewportEvents(onMoveEnd: (_) => onViewportChanged?.call()),
        ),
        nodeBuilder: (context, node) {
          final data = node.data;
          final selected = controller.selectedNodeIds.contains(node.id);
          return GestureDetector(
            onTap: () => onNodeTap(node.id),
            child: LayerNodeWidget(
              name: data.layerName,
              enabled: data.enabled,
              workerCount: data.workerCount,
              outputTypes: data.outputTypes,
              runningTasks: data.runningTasks,
              isSelected: selected,
            ),
          );
        },
      ),
    );
  }
}
