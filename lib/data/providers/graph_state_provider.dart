import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gyeol/data/providers/core_providers.dart';

class GraphState {
  const GraphState({
    this.nodePositions = const {},
    this.viewportX = 0,
    this.viewportY = 0,
    this.viewportZoom = 1,
  });
  final Map<String, Offset> nodePositions;
  final double viewportX;
  final double viewportY;
  final double viewportZoom;

  GraphState copyWith({
    Map<String, Offset>? nodePositions,
    double? viewportX,
    double? viewportY,
    double? viewportZoom,
  }) {
    return GraphState(
      nodePositions: nodePositions ?? this.nodePositions,
      viewportX: viewportX ?? this.viewportX,
      viewportY: viewportY ?? this.viewportY,
      viewportZoom: viewportZoom ?? this.viewportZoom,
    );
  }
}

GraphState _safeGraphState(GraphState? s) {
  return GraphState(
    nodePositions: s?.nodePositions ?? const {},
    viewportX: s?.viewportX ?? 0,
    viewportY: s?.viewportY ?? 0,
    viewportZoom: s?.viewportZoom ?? 1,
  );
}

final graphStateProvider =
    AsyncNotifierProvider<GraphStateNotifier, GraphState>(
      GraphStateNotifier.new,
    );

class GraphStateNotifier extends AsyncNotifier<GraphState> {
  @override
  Future<GraphState> build() async {
    final repo = ref.watch(repositoryProvider);
    final positions = await repo.graph.loadNodePositions();
    final viewport = await repo.graph.loadViewport();
    return GraphState(
      nodePositions: positions,
      viewportX: viewport.$1,
      viewportY: viewport.$2,
      viewportZoom: viewport.$3,
    );
  }

  Future<void> savePositions(Map<String, Offset> positions) async {
    final repo = ref.read(repositoryProvider);
    await repo.graph.saveNodePositions(positions);
    state = AsyncData(
      _safeGraphState(state.valueOrNull).copyWith(nodePositions: positions),
    );
  }

  Future<void> saveViewport(double x, double y, double zoom) async {
    final repo = ref.read(repositoryProvider);
    await repo.graph.saveViewport(x, y, zoom);
    state = AsyncData(
      _safeGraphState(
        state.valueOrNull,
      ).copyWith(viewportX: x, viewportY: y, viewportZoom: zoom),
    );
  }

  Future<void> saveViewportSilent(double x, double y, double zoom) async {
    final repo = ref.read(repositoryProvider);
    await repo.graph.saveViewport(x, y, zoom);
  }

  Future<void> savePositionsSilent(Map<String, Offset> positions) async {
    final repo = ref.read(repositoryProvider);
    await repo.graph.saveNodePositions(positions);
  }

  Future<void> clearPositions() async {
    final repo = ref.read(repositoryProvider);
    await repo.graph.saveNodePositions({});
    state = AsyncData(
      _safeGraphState(state.valueOrNull).copyWith(nodePositions: {}),
    );
  }
}
