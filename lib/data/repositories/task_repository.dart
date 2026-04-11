import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/models/task_models.dart';

class TaskRepository {
  TaskRepository(this._db);
  final AppDatabase _db;

  Future<String> createTask(
    String taskType,
    Object? payload,
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

  Stream<List<AppTask>> watchTasks({int limit = 100, int offset = 0}) {
    return _db
        .watchTasks(limit: limit, offset: offset)
        .map((rows) => rows.map(_taskFromRow).toList());
  }

  Future<int> getQueueSize() => _db.getQueueSize();

  Future<void> saveTask(AppTask task) {
    return _db.saveTask(_taskToCompanion(task));
  }

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
}
