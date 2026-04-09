import 'package:flutter/material.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:vyuh_node_flow/vyuh_node_flow.dart';

const double kNodeWidth = 240;
const double kNodeHeight = 120;
const double kRankSep = 140;
const double kNodeSep = 60;

class LayerGraphData {
  const LayerGraphData({
    required this.layerName,
    required this.inputTypes,
    required this.outputTypes,
    required this.workerNames,
    required this.enabled,
    this.runningTasks = 0,
  });
  final String layerName;
  final List<String> inputTypes;
  final List<String> outputTypes;
  final List<String> workerNames;
  final bool enabled;
  final int runningTasks;
}

List<Node<LayerGraphData>> buildNodes(
  List<LayerDefinition> layers,
  List<AppTask> tasks,
) {
  if (layers.isEmpty) return [];

  final runningByLayer = <String, int>{};
  for (final task in tasks) {
    if (task.status == TaskStatus.running && task.layerName != null) {
      runningByLayer[task.layerName!] =
          (runningByLayer[task.layerName!] ?? 0) + 1;
    }
  }

  final sorted = List<LayerDefinition>.from(layers)
    ..sort((a, b) => a.order.compareTo(b.order));

  final positions = _layoutLR(sorted);

  return sorted.map((layer) {
    return Node<LayerGraphData>(
      id: layer.name,
      type: 'layer',
      position: positions[layer.name]!,
      size: const Size(kNodeWidth, kNodeHeight),
      data: LayerGraphData(
        layerName: layer.name,
        inputTypes: layer.inputTypes,
        outputTypes: layer.outputTypes,
        workerNames: layer.workerNames,
        enabled: layer.enabled,
        runningTasks: runningByLayer[layer.name] ?? 0,
      ),
      ports: [
        Port(
          id: '${layer.name}-in',
          name: 'In',
          type: PortType.input,
          offset: const Offset(0, 40),
          size: const Size(16, 16),
          multiConnections: true,
        ),
        Port(
          id: '${layer.name}-out',
          name: 'Out',
          position: PortPosition.right,
          type: PortType.output,
          offset: const Offset(0, 40),
          size: const Size(16, 16),
          multiConnections: true,
        ),
      ],
    );
  }).toList();
}

List<Connection<void>> buildConnections(
  List<LayerDefinition> layers,
  Set<(String, String)> removedConnections,
) {
  final sorted = List<LayerDefinition>.from(layers)
    ..sort((a, b) => a.order.compareTo(b.order));

  final connections = <Connection<void>>[];
  var connIndex = 0;

  for (var i = 0; i < sorted.length; i++) {
    for (var j = 0; j < sorted.length; j++) {
      if (i == j) continue;
      final srcName = sorted[i].name;
      final destName = sorted[j].name;
      if (removedConnections.contains((srcName, destName))) continue;

      final overlap = sorted[i].outputTypes.toSet().intersection(
        sorted[j].inputTypes.toSet(),
      );
      if (overlap.isNotEmpty) {
        connections.add(
          Connection<void>(
            id: 'conn-${connIndex++}',
            sourceNodeId: srcName,
            sourcePortId: '$srcName-out',
            targetNodeId: destName,
            targetPortId: '$destName-in',
          ),
        );
      }
    }
  }

  return connections;
}

Map<String, Offset> _layoutLR(List<LayerDefinition> sorted) {
  final result = <String, Offset>{};
  final byDepth = <int, List<LayerDefinition>>{};

  for (final layer in sorted) {
    byDepth.putIfAbsent(layer.order, () => []).add(layer);
  }

  final depths = byDepth.keys.toList()..sort();
  for (final depth in depths) {
    final group = byDepth[depth]!;
    for (var i = 0; i < group.length; i++) {
      final x = 80.0 + (depths.indexOf(depth) * (kNodeWidth + kRankSep));
      final y = 80.0 + (i * (kNodeHeight + kNodeSep));
      result[group[i].name] = Offset(x, y);
    }
  }

  return result;
}
