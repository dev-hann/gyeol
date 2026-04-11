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
    required this.workerCount,
    required this.enabled,
    this.runningTasks = 0,
  });
  final String layerName;
  final List<String> inputTypes;
  final List<String> outputTypes;
  final int workerCount;
  final bool enabled;
  final int runningTasks;
}

List<Node<LayerGraphData>> buildNodes(
  List<LayerDefinition> layers,
  List<AppTask> tasks,
  List<WorkerDefinition> workers,
) {
  if (layers.isEmpty) return [];

  final runningByLayer = <String, int>{};
  for (final task in tasks) {
    if (task.status == TaskStatus.running && task.layerName != null) {
      runningByLayer[task.layerName!] =
          (runningByLayer[task.layerName!] ?? 0) + 1;
    }
  }

  final positions = layoutGraph(layers);

  return layers.map((layer) {
    final layerWorkerCount = workers
        .where((w) => w.layerName == layer.name)
        .length;
    return Node<LayerGraphData>(
      id: layer.name,
      type: 'layer',
      position: positions[layer.name]!,
      size: const Size(kNodeWidth, kNodeHeight),
      data: LayerGraphData(
        layerName: layer.name,
        inputTypes: layer.inputTypes,
        outputTypes: layer.outputTypes,
        workerCount: layerWorkerCount,
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

Map<String, Offset> layoutGraph(List<LayerDefinition> layers) {
  if (layers.isEmpty) return {};

  final names = layers.map((l) => l.name).toSet();
  final edges = <(String, String)>[];
  for (final src in layers) {
    for (final dst in layers) {
      if (src.name == dst.name) continue;
      if (src.outputTypes
          .toSet()
          .intersection(dst.inputTypes.toSet())
          .isNotEmpty) {
        edges.add((src.name, dst.name));
      }
    }
  }

  final incoming = <String, Set<String>>{};
  final outgoing = <String, Set<String>>{};
  for (final name in names) {
    incoming[name] = {};
    outgoing[name] = {};
  }
  for (final (src, dst) in edges) {
    if (names.contains(src) && names.contains(dst)) {
      outgoing[src]!.add(dst);
      incoming[dst]!.add(src);
    }
  }

  final rank = <String, int>{};
  final visited = <String>{};

  void assignRank(String node, int r) {
    if (visited.contains(node)) return;
    visited.add(node);
    rank[node] = r;
    for (final child in outgoing[node]!) {
      assignRank(child, r + 1);
    }
  }

  final sources = names.where((n) => incoming[n]!.isEmpty).toList()..sort();
  for (final s in sources) {
    assignRank(s, 0);
  }
  for (final name in names) {
    if (!visited.contains(name)) {
      rank[name] = 0;
    }
  }

  final byRank = <int, List<String>>{};
  for (final entry in rank.entries) {
    byRank.putIfAbsent(entry.value, () => []).add(entry.key);
  }

  final sortedRanks = byRank.keys.toList()..sort();
  final baryCenter = <String, double>{};

  for (final r in sortedRanks) {
    final nodesInRank = byRank[r]!;
    if (r == sortedRanks.first) {
      for (var i = 0; i < nodesInRank.length; i++) {
        baryCenter[nodesInRank[i]] = i.toDouble();
      }
      continue;
    }

    final prevRank = sortedRanks[sortedRanks.indexOf(r) - 1];
    final prevNodes = byRank[prevRank]!;
    final prevIndex = <String, int>{};
    for (var i = 0; i < prevNodes.length; i++) {
      prevIndex[prevNodes[i]] = i;
    }

    for (final node in nodesInRank) {
      final preds = incoming[node]!.where(prevIndex.containsKey).toList();
      if (preds.isEmpty) {
        baryCenter[node] = nodesInRank.indexOf(node).toDouble();
      } else {
        baryCenter[node] =
            preds.map((p) => prevIndex[p]!.toDouble()).reduce((a, b) => a + b) /
            preds.length;
      }
    }

    nodesInRank.sort((a, b) => baryCenter[a]!.compareTo(baryCenter[b]!));
  }

  final result = <String, Offset>{};
  for (final r in sortedRanks) {
    final group = byRank[r]!;
    for (var i = 0; i < group.length; i++) {
      final x = 80.0 + (r * (kNodeWidth + kRankSep));
      final y = 80.0 + (i * (kNodeHeight + kNodeSep));
      result[group[i]] = Offset(x, y);
    }
  }

  return result;
}
