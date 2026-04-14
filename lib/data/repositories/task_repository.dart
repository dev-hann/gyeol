import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/models/task_models.dart';

class TaskRepository {
  TaskRepository(this._db);
  final AppDatabase _db;

  Future<int> createTask(
    String taskType,
    Object? payload,
    TaskPriority priority,
  ) async {
    final task = AppTask.create(taskType, payload, priority);
    final id = await _db
        .into(_db.tasks)
        .insert(
          TasksCompanion.insert(
            uuid: task.uuid,
            taskType: task.taskType,
            payload: jsonEncode(task.payload),
            priority: task.priority.name,
            status: task.status.name,
            retryCount: Value(task.retryCount),
            maxRetries: Value(task.maxRetries),
            depth: Value(task.depth),
            parentTaskId: Value(task.parentTaskId),
            layerId: Value(task.layerId),
            workerId: Value(task.workerId),
            createdAt: Value(task.createdAt),
            updatedAt: Value(task.updatedAt),
          ),
        );
    return id;
  }

  Future<AppTask?> getTask(String id) async {
    final row = await _db.getTask(id);
    return row != null ? _taskFromRow(row) : null;
  }

  Future<List<AppTask>> listTasks({int limit = 100, int offset = 0}) async {
    final rows = await _db.listTasks(limit: limit, offset: offset);
    return rows.map(_taskFromRow).toList();
  }

  Future<List<AppTask>> listTasksByThread(
    int threadId, {
    int limit = 200,
  }) async {
    final rows = await _db.listTasksByThread(threadId, limit: limit);
    return rows.map(_taskFromRow).toList();
  }

  Stream<List<AppTask>> watchTasks({int limit = 100, int offset = 0}) {
    return _db
        .watchTasks(limit: limit, offset: offset)
        .map((rows) => rows.map(_taskFromRow).toList());
  }

  Stream<List<AppTask>> watchTasksByThread(int threadId, {int limit = 200}) {
    return _db
        .watchTasksByThread(threadId, limit: limit)
        .map((rows) => rows.map(_taskFromRow).toList());
  }

  Future<int> getQueueSize() => _db.getQueueSize();

  Future<void> saveTask(AppTask task) {
    return _db.saveTask(_taskToCompanion(task));
  }

  TasksCompanion _taskToCompanion(AppTask t) {
    return TasksCompanion(
      id: t.id == 0 ? const Value.absent() : Value(t.id),
      uuid: Value(t.uuid),
      taskType: Value(t.taskType),
      payload: Value(jsonEncode(t.payload)),
      priority: Value(t.priority.name),
      status: Value(t.status.name),
      retryCount: Value(t.retryCount),
      maxRetries: Value(t.maxRetries),
      depth: Value(t.depth),
      parentTaskId: Value(t.parentTaskId),
      layerId: Value(t.layerId),
      workerId: Value(t.workerId),
      threadId: Value(t.threadId),
      createdAt: Value(t.createdAt),
      updatedAt: Value(t.updatedAt),
    );
  }

  Object? _safeDecodePayload(String payload) {
    try {
      return jsonDecode(payload);
    } on FormatException {
      return null;
    }
  }

  AppTask _taskFromRow(Task r) {
    return AppTask(
      id: r.id,
      uuid: r.uuid,
      taskType: r.taskType,
      payload: _safeDecodePayload(r.payload),
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
      layerId: r.layerId,
      workerId: r.workerId,
      threadId: r.threadId,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
    );
  }
}
