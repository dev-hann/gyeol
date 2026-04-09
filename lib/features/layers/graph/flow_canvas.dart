import 'package:flutter/material.dart';
import 'package:flutter_flow_chart/flutter_flow_chart.dart';
import 'package:gyeol/features/layers/graph/graph_utils.dart';
import 'package:gyeol/features/layers/graph/layer_node_widget.dart';

class FlowCanvas extends StatelessWidget {
  const FlowCanvas({
    required this.dashboard,
    required this.onNodeTap,
    super.key,
  });
  final Dashboard<LayerGraphData> dashboard;
  final void Function(String layerName) onNodeTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: FlowChart<LayerGraphData>(
        dashboard: dashboard,
        onElementPressed: (context, position, element) {
          final data = element.elementData;
          if (data != null) {
            onNodeTap(data.layerName);
          }
        },
        onDashboardTapped: (context, position) {},
        customElementBuilder: (context, element) {
          final data = element.elementData;
          if (data == null) {
            return const SizedBox.shrink();
          }
          return LayerNodeWidget(
            name: data.layerName,
            enabled: data.enabled,
            workerCount: data.workerNames.length,
            outputTypes: data.outputTypes,
            runningTasks: data.runningTasks,
          );
        },
      ),
    );
  }
}
