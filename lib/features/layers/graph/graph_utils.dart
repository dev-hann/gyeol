import 'package:flutter/material.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/repositories/connection_repository.dart';
import 'package:vyuh_node_flow/vyuh_node_flow.dart';

const double kNodeWidth = 240;
const double kNodeHeight = 120;
const double kRankSep = 140;
const double kNodeSep = 60;

class LayerGraphData {
  const LayerGraphData({
    required this.layerId,
    required this.layerName,
    required this.inputTypes,
    required this.outputTypes,
    required this.workerCount,
    required this.enabled,
    this.runningTasks = 0,
  });
  final int layerId;
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
  List<LayerConnectionData> connections,
) {
  if (layers.isEmpty) return [];

  final runningByLayer = <int, int>{};
  for (final task in tasks) {
    if (task.status == TaskStatus.running && task.layerId != null) {
      runningByLayer[task.layerId!] = (runningByLayer[task.layerId!] ?? 0) + 1;
    }
  }

  final positions = layoutGraph(layers, connections);

  return layers.map((layer) {
    final nodeId = layer.id.toString();
    final layerWorkerCount = workers.where((w) => w.layerId == layer.id).length;
    return Node<LayerGraphData>(
      id: nodeId,
      type: 'layer',
      position: positions[nodeId]!,
      size: const Size(kNodeWidth, kNodeHeight),
      data: LayerGraphData(
        layerId: layer.id,
        layerName: layer.name,
        inputTypes: layer.inputTypes,
        outputTypes: layer.outputTypes,
        workerCount: layerWorkerCount,
        enabled: layer.enabled,
        runningTasks: runningByLayer[layer.id] ?? 0,
      ),
      ports: [
        Port(
          id: '$nodeId-in',
          name: 'In',
          type: PortType.input,
          offset: const Offset(0, 40),
          size: const Size(16, 16),
          multiConnections: true,
        ),
        Port(
          id: '$nodeId-out',
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

List<Connection<void>> buildConnections(List<LayerConnectionData> connections) {
  var connIndex = 0;
  return connections.map((c) {
    final srcId = c.sourceLayerId.toString();
    final dstId = c.targetLayerId.toString();
    return Connection<void>(
      id: 'conn-${connIndex++}',
      sourceNodeId: srcId,
      sourcePortId: '$srcId-out',
      targetNodeId: dstId,
      targetPortId: '$dstId-in',
    );
  }).toList();
}

Map<String, Offset> layoutGraph(
  List<LayerDefinition> layers,
  List<LayerConnectionData> connections,
) {
  if (layers.isEmpty) return {};

  final nodeIds = layers.map((l) => l.id.toString()).toSet();

  final edges = <(String, String)>[];
  for (final c in connections) {
    final srcId = c.sourceLayerId.toString();
    final dstId = c.targetLayerId.toString();
    if (nodeIds.contains(srcId) && nodeIds.contains(dstId)) {
      edges.add((srcId, dstId));
    }
  }

  final incoming = <String, Set<String>>{};
  final outgoing = <String, Set<String>>{};
  for (final id in nodeIds) {
    incoming[id] = {};
    outgoing[id] = {};
  }
  for (final (src, dst) in edges) {
    outgoing[src]!.add(dst);
    incoming[dst]!.add(src);
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

  final sources = nodeIds.where((n) => incoming[n]!.isEmpty).toList()..sort();
  for (final s in sources) {
    assignRank(s, 0);
  }
  for (final id in nodeIds) {
    if (!visited.contains(id)) {
      rank[id] = 0;
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
