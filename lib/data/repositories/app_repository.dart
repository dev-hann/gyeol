import 'dart:convert';
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
}
