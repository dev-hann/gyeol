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
    super.key,
  });
  final NodeFlowController<LayerGraphData, void> controller;
  final void Function(String layerName) onNodeTap;
  final VoidCallback? onNodeDragEnd;

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
        ),
        nodeBuilder: (context, node) {
          final data = node.data;
          return GestureDetector(
            onTap: () => onNodeTap(data.layerName),
            child: LayerNodeWidget(
              name: data.layerName,
              enabled: data.enabled,
              workerCount: data.workerNames.length,
              outputTypes: data.outputTypes,
              runningTasks: data.runningTasks,
            ),
          );
        },
      ),
    );
  }
}
