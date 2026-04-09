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
    dynamic payload,
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
  });
  final Map<String, Offset> nodePositions;
  final Set<(String, String)> removedConnections;

  GraphState copyWith({
    Map<String, Offset>? nodePositions,
    Set<(String, String)>? removedConnections,
  }) {
    return GraphState(
      nodePositions: nodePositions ?? this.nodePositions,
      removedConnections: removedConnections ?? this.removedConnections,
    );
  }
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
    return GraphState(nodePositions: positions, removedConnections: removed);
  }

  Future<void> savePositions(Map<String, Offset> positions) async {
    final repo = ref.read(repositoryProvider);
    await repo.saveNodePositions(positions);
    final current = state.valueOrNull ?? const GraphState();
    state = AsyncData(current.copyWith(nodePositions: positions));
  }

  Future<void> saveRemovedConnections(Set<(String, String)> removed) async {
    final repo = ref.read(repositoryProvider);
    await repo.saveRemovedConnections(removed);
    final current = state.valueOrNull ?? const GraphState();
    state = AsyncData(current.copyWith(removedConnections: removed));
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
