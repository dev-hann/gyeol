import 'dart:convert';
import 'dart:ui';
import 'package:drift/drift.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/models/app_models.dart';

class AppRepository {
  AppRepository(this._db);
  final AppDatabase _db;

  // ── Tasks ──

  Future<String> createTask(
    String taskType,
    dynamic payload,
    TaskPriority priority,
  ) async {
    final task = AppTask.create(taskType, payload, priority);
    await _db.saveTask(_taskToCompanion(task));
    return task.id;
  }

  Future<AppTask?> getTask(String id) async {
    final row = await _db.getTask(id);
    return row != null ? _taskFromRow(row) : null;
  }

  Future<List<AppTask>> listTasks({int limit = 100, int offset = 0}) async {
    final rows = await _db.listTasks(limit: limit, offset: offset);
    return rows.map(_taskFromRow).toList();
  }

  Future<int> getQueueSize() => _db.getQueueSize();

  Future<void> saveTask(AppTask task) {
    return _db.saveTask(_taskToCompanion(task));
  }

  // ── Layers ──

  Future<void> saveLayer(LayerDefinition layer) {
    return _db.saveLayer(
      LayersCompanion.insert(
        name: layer.name,
        inputTypes: jsonEncode(layer.inputTypes),
        outputTypes: jsonEncode(layer.outputTypes),
        workerNames: jsonEncode(layer.workerNames),
        sortOrder: Value(layer.order),
        enabled: Value(layer.enabled),
      ),
    );
  }

  Future<List<LayerDefinition>> listLayers() async {
    final rows = await _db.listLayers();
    return rows
        .map(
          (r) => LayerDefinition(
            name: r.name,
            inputTypes: List<String>.from(jsonDecode(r.inputTypes) as List),
            outputTypes: List<String>.from(jsonDecode(r.outputTypes) as List),
            workerNames: List<String>.from(jsonDecode(r.workerNames) as List),
            order: r.sortOrder,
            enabled: r.enabled,
          ),
        )
        .toList();
  }

  Future<void> deleteLayer(String name) => _db.deleteLayer(name);

  // ── Workers ──

  Future<void> saveWorker(WorkerDefinition worker) {
    return _db.saveWorker(
      WorkersCompanion.insert(
        name: worker.name,
        layerName: worker.layerName,
        systemPrompt: worker.systemPrompt,
        model: Value(worker.model),
        temperature: Value(worker.temperature),
        maxTokens: Value(worker.maxTokens),
        enabled: Value(worker.enabled),
      ),
    );
  }

  Future<WorkerDefinition?> getWorker(String name) async {
    final row = await _db.getWorker(name);
    return row != null ? _workerFromRow(row) : null;
  }

  Future<List<WorkerDefinition>> listWorkers() async {
    final rows = await _db.listWorkers();
    return rows.map(_workerFromRow).toList();
  }

  Future<void> deleteWorker(String name) => _db.deleteWorker(name);

  // ── Threads ──

  Future<void> saveThread(ThreadDefinition thread) {
    return _db.saveThread(
      ThreadsCompanion.insert(
        name: thread.name,
        path: thread.path,
        layerNames: jsonEncode(thread.layerNames),
        enabled: Value(thread.enabled),
        status: Value(thread.status.name),
      ),
    );
  }

  Future<List<ThreadDefinition>> listThreads() async {
    final rows = await _db.listThreads();
    return rows.map(_threadFromRow).toList();
  }

  Future<ThreadDefinition?> getThread(String name) async {
    final row = await _db.getThread(name);
    return row != null ? _threadFromRow(row) : null;
  }

  Future<void> deleteThread(String name) => _db.deleteThread(name);

  // ── Settings ──

  Future<ProviderSettings> getSettings() async {
    final json = await _db.getSettingsJson();
    if (json == null) return const ProviderSettings();
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, dynamic>) {
        return const ProviderSettings();
      }
      return ProviderSettings.fromJson(decoded);
    } on FormatException {
      return const ProviderSettings();
    }
  }

  Future<void> saveSettings(ProviderSettings settings) {
    return _db.saveSettings(jsonEncode(settings.toJson()));
  }

  // ── Graph State ──

  Future<Map<String, Offset>> loadNodePositions() async {
    final json = await _db.getJsonValue('graph_node_positions');
    if (json == null) return {};
    try {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      return decoded.map((k, v) {
        final list = v as List;
        return MapEntry(
          k,
          Offset((list[0] as num).toDouble(), (list[1] as num).toDouble()),
        );
      });
    } on FormatException {
      return {};
    }
  }

  Future<void> saveNodePositions(Map<String, Offset> positions) {
    final encoded = jsonEncode(
      positions.map((k, v) => MapEntry(k, [v.dx, v.dy])),
    );
    return _db.saveJsonValue('graph_node_positions', encoded);
  }

  Future<Set<(String, String)>> loadRemovedConnections() async {
    final json = await _db.getJsonValue('graph_removed_connections');
    if (json == null) return {};
    try {
      final decoded = jsonDecode(json) as List;
      return decoded.map((e) {
        final list = e as List;
        return (list[0] as String, list[1] as String);
      }).toSet();
    } on FormatException {
      return {};
    }
  }

  Future<void> saveRemovedConnections(Set<(String, String)> connections) {
    final encoded = jsonEncode(connections.map((c) => [c.$1, c.$2]).toList());
    return _db.saveJsonValue('graph_removed_connections', encoded);
  }

  Future<Set<(String, String)>> loadManualConnections() async {
    final json = await _db.getJsonValue('graph_manual_connections');
    if (json == null) return {};
    try {
      final decoded = jsonDecode(json) as List;
      return decoded.map((e) {
        final list = e as List;
        return (list[0] as String, list[1] as String);
      }).toSet();
    } on FormatException {
      return {};
    }
  }

  Future<void> saveManualConnections(Set<(String, String)> connections) {
    final encoded = jsonEncode(connections.map((c) => [c.$1, c.$2]).toList());
    return _db.saveJsonValue('graph_manual_connections', encoded);
  }

  // ── Execution Logs ──

  Future<void> logExecution({
    required String taskId,
    required String status,
    String? workerName,
    String? message,
  }) {
    return _db.logExecution(
      taskId: taskId,
      workerName: workerName,
      status: status,
      message: message,
    );
  }

  Future<List<ExecutionLog>> listExecutionLogs({
    String? taskId,
    int limit = 200,
  }) {
    return _db.listExecutionLogs(taskId: taskId, limit: limit);
  }

  // ── Mappers ──

  TasksCompanion _taskToCompanion(AppTask t) {
    return TasksCompanion.insert(
      id: t.id,
      taskType: t.taskType,
      payload: jsonEncode(t.payload),
      priority: t.priority.name,
      status: t.status.name,
      retryCount: Value(t.retryCount),
      maxRetries: Value(t.maxRetries),
      depth: Value(t.depth),
      parentTaskId: Value(t.parentTaskId),
      layerName: Value(t.layerName),
      workerName: Value(t.workerName),
      createdAt: t.createdAt,
      updatedAt: t.updatedAt,
    );
  }

  AppTask _taskFromRow(Task r) {
    return AppTask(
      id: r.id,
      taskType: r.taskType,
      payload: jsonDecode(r.payload),
      priority: TaskPriority.values.firstWhere(
        (p) => p.name == r.priority,
        orElse: () => TaskPriority.low,
      ),
      status: TaskStatus.values.firstWhere(
        (s) => s.name == r.status,
        orElse: () => TaskStatus.pending,
      ),
      retryCount: r.retryCount,
      maxRetries: r.maxRetries,
      depth: r.depth,
      parentTaskId: r.parentTaskId,
      layerName: r.layerName,
      workerName: r.workerName,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
    );
  }

  WorkerDefinition _workerFromRow(Worker r) {
    return WorkerDefinition(
      name: r.name,
      layerName: r.layerName,
      systemPrompt: r.systemPrompt,
      model: r.model,
      temperature: r.temperature,
      maxTokens: r.maxTokens,
      enabled: r.enabled,
    );
  }

  ThreadDefinition _threadFromRow(Thread r) {
    return ThreadDefinition(
      name: r.name,
      path: r.path,
      layerNames: List<String>.from(jsonDecode(r.layerNames) as List),
      enabled: r.enabled,
      status: ThreadStatus.values.firstWhere(
        (s) => s.name == r.status,
        orElse: () => ThreadStatus.idle,
      ),
    );
  }
}
