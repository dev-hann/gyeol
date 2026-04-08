import 'package:flutter/material.dart';
import 'package:flutter_flow_chart/flutter_flow_chart.dart';
import 'package:gyeol/data/models/app_models.dart';

const double kNodeWidth = 240;
const double kNodeHeight = 120;
const double kRankSep = 140;
const double kNodeSep = 60;

class LayerGraphData {
  final String layerName;
  final List<String> inputTypes;
  final List<String> outputTypes;
  final List<String> workerNames;
  final bool enabled;
  final int runningTasks;

  const LayerGraphData({
    required this.layerName,
    required this.inputTypes,
    required this.outputTypes,
    required this.workerNames,
    required this.enabled,
    this.runningTasks = 0,
  });
}

class DataSerializerImpl
    with DataSerializer<LayerGraphData, Map<String, dynamic>> {
  @override
  LayerGraphData? fromJson(Map<String, dynamic>? source) {
    if (source == null) return null;
    return LayerGraphData(
      layerName: source['layerName'] as String? ?? '',
      inputTypes: List<String>.from(source['inputTypes'] as List? ?? []),
      outputTypes: List<String>.from(source['outputTypes'] as List? ?? []),
      workerNames: List<String>.from(source['workerNames'] as List? ?? []),
      enabled: source['enabled'] as bool? ?? true,
      runningTasks: source['runningTasks'] as int? ?? 0,
    );
  }

  @override
  Map<String, dynamic>? toJson(LayerGraphData? data) {
    if (data == null) return null;
    return {
      'layerName': data.layerName,
      'inputTypes': data.inputTypes,
      'outputTypes': data.outputTypes,
      'workerNames': data.workerNames,
      'enabled': data.enabled,
      'runningTasks': data.runningTasks,
    };
  }
}

Dashboard<LayerGraphData> buildDashboard(
  List<LayerDefinition> layers,
  List<AppTask> tasks,
) {
  final dashboard = Dashboard<LayerGraphData>(
    dataSerializer: DataSerializerImpl(),
    defaultArrowStyle: ArrowStyle.curve,
    minimumZoomFactor: 0.3,
  );

  dashboard.gridBackgroundParams = GridBackgroundParams(
    backgroundColor: const Color(0xFF0f0f11),
    gridColor: const Color(0xFF2e2e33),
    gridSquare: 20.0,
    gridThickness: 1.0,
  );

  if (layers.isEmpty) return dashboard;

  final runningByLayer = <String, int>{};
  for (final task in tasks) {
    if (task.status == TaskStatus.running && task.layerName != null) {
      runningByLayer[task.layerName!] =
          (runningByLayer[task.layerName!] ?? 0) + 1;
    }
  }

  final sorted = List<LayerDefinition>.from(layers)
    ..sort((a, b) => a.order.compareTo(b.order));

  final elements = <String, FlowElement<LayerGraphData>>{};
  final positions = _layoutLR(sorted);

  final idToName = <String, String>{};

  for (final layer in sorted) {
    final pos = positions[layer.name]!;
    final element = FlowElement<LayerGraphData>(
      position: pos,
      size: const Size(kNodeWidth, kNodeHeight),
      text: layer.name,
      kind: ElementKind.custom,
      handlers: const [Handler.leftCenter, Handler.rightCenter],
      handlerSize: 12,
      backgroundColor: const Color(0xFF18181b),
      borderColor: layer.enabled
          ? const Color(0xFF6d5acf)
          : const Color(0xFF71717a),
      borderThickness: 2,
      elevation: 0,
      isDraggable: true,
      isResizable: false,
      isConnectable: true,
      elementData: LayerGraphData(
        layerName: layer.name,
        inputTypes: layer.inputTypes,
        outputTypes: layer.outputTypes,
        workerNames: layer.workerNames,
        enabled: layer.enabled,
        runningTasks: runningByLayer[layer.name] ?? 0,
      ),
    );
    elements[layer.name] = element;
    idToName[element.id] = layer.name;
    dashboard.addElement(element);
  }

  for (int i = 0; i < sorted.length; i++) {
    for (int j = 0; j < sorted.length; j++) {
      if (i == j) continue;
      final overlap = sorted[i].outputTypes.toSet().intersection(
        sorted[j].inputTypes.toSet(),
      );
      if (overlap.isNotEmpty) {
        final src = elements[sorted[i].name]!;
        final destId = elements[sorted[j].name]!.id;
        final hasRunning =
            (runningByLayer[sorted[i].name] ?? 0) > 0 ||
            (runningByLayer[sorted[j].name] ?? 0) > 0;

        dashboard.addNextById(
          src,
          destId,
          ArrowParams(
            thickness: 2,
            color: hasRunning
                ? const Color(0xFF3b82f6)
                : const Color(0xFF6d5acf),
            startArrowPosition: Alignment.centerRight,
            endArrowPosition: Alignment.centerLeft,
          ),
        );
      }
    }
  }

  return dashboard;
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
    for (int i = 0; i < group.length; i++) {
      final x = 80.0 + (depths.indexOf(depth) * (kNodeWidth + kRankSep));
      final y = 80.0 + (i * (kNodeHeight + kNodeSep));
      result[group[i].name] = Offset(x, y);
    }
  }

  return result;
}

void syncDashboard(
  Dashboard<LayerGraphData> dashboard,
  List<LayerDefinition> layers,
  List<AppTask> tasks,
) {
  dashboard.removeAllElements();
  final newDb = buildDashboard(layers, tasks);
  for (final e in newDb.elements) {
    dashboard.addElement(e);
  }
}
