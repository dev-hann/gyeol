import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gyeol/data/providers/core_providers.dart';

class GraphState {
  const GraphState({
    this.nodePositions = const {},
    this.removedConnections = const {},
    this.viewportX = 0,
    this.viewportY = 0,
    this.viewportZoom = 1,
  });
  final Map<String, Offset> nodePositions;
  final Set<(String, String)> removedConnections;
  final double viewportX;
  final double viewportY;
  final double viewportZoom;

  GraphState copyWith({
    Map<String, Offset>? nodePositions,
    Set<(String, String)>? removedConnections,
    double? viewportX,
    double? viewportY,
    double? viewportZoom,
  }) {
    return GraphState(
      nodePositions: nodePositions ?? this.nodePositions,
      removedConnections: removedConnections ?? this.removedConnections,
      viewportX: viewportX ?? this.viewportX,
      viewportY: viewportY ?? this.viewportY,
      viewportZoom: viewportZoom ?? this.viewportZoom,
    );
  }
}

GraphState _safeGraphState(GraphState? s) {
  return GraphState(
    nodePositions: s?.nodePositions ?? const {},
    removedConnections: s?.removedConnections ?? const {},
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
    final removed = await repo.graph.loadRemovedConnections();
    final viewport = await repo.graph.loadViewport();
    return GraphState(
      nodePositions: positions,
      removedConnections: removed,
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

  Future<void> saveRemovedConnections(Set<(String, String)> removed) async {
    final repo = ref.read(repositoryProvider);
    await repo.graph.saveRemovedConnections(removed);
    state = AsyncData(
      _safeGraphState(state.valueOrNull).copyWith(removedConnections: removed),
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

  Future<void> clearPositions() async {
    final repo = ref.read(repositoryProvider);
    await repo.graph.saveNodePositions({});
    state = AsyncData(
      _safeGraphState(state.valueOrNull).copyWith(nodePositions: {}),
    );
  }
}
