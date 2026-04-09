import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/repositories/app_repository.dart';
import 'package:gyeol/engine/queue/task_queue.dart';
import 'package:gyeol/engine/scheduler.dart';

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

final repositoryProvider = Provider<AppRepository>((ref) {
  return AppRepository(ref.watch(databaseProvider));
});

final schedulerProvider = Provider<Scheduler>((ref) {
  final repo = ref.watch(repositoryProvider);
  final queue = TaskQueue();
  final registry = LayerRegistry();
  final bus = MessageBus();
  return Scheduler(
    queue: queue,
    layerRegistry: registry,
    messageBus: bus,
    repo: repo,
  );
});

// ── Tasks ──

final tasksProvider = AsyncNotifierProvider<TasksNotifier, List<AppTask>>(
  TasksNotifier.new,
);

class TasksNotifier extends AsyncNotifier<List<AppTask>> {
  @override
  Future<List<AppTask>> build() async {
    final repo = ref.watch(repositoryProvider);
    return repo.listTasks();
  }

  Future<void> refresh() async {
    final repo = ref.read(repositoryProvider);
    state = AsyncData(await repo.listTasks());
  }

  Future<String> createTask(
    String type,
    Object? payload,
    TaskPriority priority,
  ) async {
    final repo = ref.read(repositoryProvider);
    final id = await repo.createTask(type, payload, priority);
    await refresh();
    return id;
  }
}

// ── Layers ──

final layersProvider =
    AsyncNotifierProvider<LayersNotifier, List<LayerDefinition>>(
      LayersNotifier.new,
    );

class LayersNotifier extends AsyncNotifier<List<LayerDefinition>> {
  @override
  Future<List<LayerDefinition>> build() async {
    final repo = ref.watch(repositoryProvider);
    return repo.listLayers();
  }

  Future<void> refresh() async {
    final repo = ref.read(repositoryProvider);
    state = AsyncData(await repo.listLayers());
  }

  Future<void> saveLayer(LayerDefinition layer) async {
    final repo = ref.read(repositoryProvider);
    await repo.saveLayer(layer);
    await refresh();
  }

  Future<void> deleteLayer(String name) async {
    final repo = ref.read(repositoryProvider);
    await repo.deleteLayer(name);
    await refresh();
  }
}

// ── Workers ──

final workersProvider =
    AsyncNotifierProvider<WorkersNotifier, List<WorkerDefinition>>(
      WorkersNotifier.new,
    );

class WorkersNotifier extends AsyncNotifier<List<WorkerDefinition>> {
  @override
  Future<List<WorkerDefinition>> build() async {
    final repo = ref.watch(repositoryProvider);
    return repo.listWorkers();
  }

  Future<void> refresh() async {
    final repo = ref.read(repositoryProvider);
    state = AsyncData(await repo.listWorkers());
  }

  Future<void> saveWorker(WorkerDefinition worker) async {
    final repo = ref.read(repositoryProvider);
    await repo.saveWorker(worker);
    await refresh();
  }

  Future<void> deleteWorker(String name) async {
    final repo = ref.read(repositoryProvider);
    await repo.deleteWorker(name);
    await refresh();
  }
}

// ── Threads ──

final threadsProvider =
    AsyncNotifierProvider<ThreadsNotifier, List<ThreadDefinition>>(
      ThreadsNotifier.new,
    );

class ThreadsNotifier extends AsyncNotifier<List<ThreadDefinition>> {
  @override
  Future<List<ThreadDefinition>> build() async {
    final repo = ref.watch(repositoryProvider);
    return repo.listThreads();
  }

  Future<void> refresh() async {
    final repo = ref.read(repositoryProvider);
    state = AsyncData(await repo.listThreads());
  }

  Future<void> saveThread(ThreadDefinition thread) async {
    final repo = ref.read(repositoryProvider);
    await repo.saveThread(thread);
    await refresh();
  }

  Future<void> deleteThread(String name) async {
    final repo = ref.read(repositoryProvider);
    await repo.deleteThread(name);
    await refresh();
  }
}

// ── Settings ──

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, ProviderSettings>(
      SettingsNotifier.new,
    );

class SettingsNotifier extends AsyncNotifier<ProviderSettings> {
  @override
  Future<ProviderSettings> build() async {
    final repo = ref.watch(repositoryProvider);
    return repo.getSettings();
  }

  Future<void> save(ProviderSettings settings) async {
    final repo = ref.read(repositoryProvider);
    await repo.saveSettings(settings);
    state = AsyncData(settings);
  }
}

// ── Graph State ──

class GraphState {
  const GraphState({
    this.nodePositions = const {},
    this.removedConnections = const {},
    this.manualConnections = const {},
    this.viewportX = 0,
    this.viewportY = 0,
    this.viewportZoom = 1,
  });
  final Map<String, Offset> nodePositions;
  final Set<(String, String)> removedConnections;
  final Set<(String, String)> manualConnections;
  final double viewportX;
  final double viewportY;
  final double viewportZoom;

  GraphState copyWith({
    Map<String, Offset>? nodePositions,
    Set<(String, String)>? removedConnections,
    Set<(String, String)>? manualConnections,
    double? viewportX,
    double? viewportY,
    double? viewportZoom,
  }) {
    return GraphState(
      nodePositions: nodePositions ?? this.nodePositions,
      removedConnections: removedConnections ?? this.removedConnections,
      manualConnections: manualConnections ?? this.manualConnections,
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
    manualConnections: s?.manualConnections ?? const {},
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
    final positions = await repo.loadNodePositions();
    final removed = await repo.loadRemovedConnections();
    final manual = await repo.loadManualConnections();
    final viewport = await repo.loadViewport();
    return GraphState(
      nodePositions: positions,
      removedConnections: removed,
      manualConnections: manual,
      viewportX: viewport.$1,
      viewportY: viewport.$2,
      viewportZoom: viewport.$3,
    );
  }

  Future<void> savePositions(Map<String, Offset> positions) async {
    final repo = ref.read(repositoryProvider);
    await repo.saveNodePositions(positions);
    state = AsyncData(
      _safeGraphState(state.valueOrNull).copyWith(nodePositions: positions),
    );
  }

  Future<void> saveRemovedConnections(Set<(String, String)> removed) async {
    final repo = ref.read(repositoryProvider);
    await repo.saveRemovedConnections(removed);
    state = AsyncData(
      _safeGraphState(state.valueOrNull).copyWith(removedConnections: removed),
    );
  }

  Future<void> saveManualConnections(Set<(String, String)> manual) async {
    final repo = ref.read(repositoryProvider);
    await repo.saveManualConnections(manual);
    state = AsyncData(
      _safeGraphState(state.valueOrNull).copyWith(manualConnections: manual),
    );
  }

  Future<void> saveViewport(double x, double y, double zoom) async {
    final repo = ref.read(repositoryProvider);
    await repo.saveViewport(x, y, zoom);
    state = AsyncData(
      _safeGraphState(
        state.valueOrNull,
      ).copyWith(viewportX: x, viewportY: y, viewportZoom: zoom),
    );
  }
}

// ── Execution Logs ──

final logsProvider = AsyncNotifierProvider<LogsNotifier, List<ExecutionLog>>(
  LogsNotifier.new,
);

class LogsNotifier extends AsyncNotifier<List<ExecutionLog>> {
  @override
  Future<List<ExecutionLog>> build() async {
    final repo = ref.watch(repositoryProvider);
    return repo.listExecutionLogs();
  }

  Future<void> refresh({String? taskId}) async {
    final repo = ref.read(repositoryProvider);
    state = AsyncData(await repo.listExecutionLogs(taskId: taskId));
  }
}

// ── Queue Size ──

final queueSizeProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(repositoryProvider);
  return repo.getQueueSize();
});

// ── Run Scheduler ──

final runSchedulerProvider = FutureProvider.family<List<WorkerResult>, void>((
  ref,
  _,
) async {
  final scheduler = ref.read(schedulerProvider);
  final results = await scheduler.runOnce();
  ref
    ..invalidate(tasksProvider)
    ..invalidate(queueSizeProvider)
    ..invalidate(logsProvider);
  return results;
});
