import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

enum TaskPriority { low, medium, high }

enum TaskStatus { pending, running, done, failed }

@immutable
class AppTask {
  const AppTask({
    required this.id,
    required this.uuid,
    required this.taskType,
    required this.payload,
    required this.priority,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.retryCount = 0,
    this.maxRetries = 3,
    this.depth = 0,
    this.parentTaskId,
    this.layerId,
    this.workerId,
    this.threadId,
  });

  factory AppTask.create(
    String taskType,
    Object? payload,
    TaskPriority priority,
  ) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return AppTask(
      id: 0,
      uuid: const Uuid().v4(),
      taskType: taskType,
      payload: payload,
      priority: priority,
      status: TaskStatus.pending,
      createdAt: now,
      updatedAt: now,
    );
  }

  final int id;
  final String uuid;
  final String taskType;
  final Object? payload;
  final TaskPriority priority;
  final TaskStatus status;
  final int retryCount;
  final int maxRetries;
  final int depth;
  final int? parentTaskId;
  final int? layerId;
  final int? workerId;
  final int? threadId;
  final int createdAt;
  final int updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AppTask && uuid == other.uuid;

  @override
  int get hashCode => uuid.hashCode;

  AppTask copyWith({
    int? id,
    String? uuid,
    TaskStatus? status,
    int? layerId,
    int? workerId,
    int? threadId,
    int? retryCount,
    int? depth,
    int? parentTaskId,
    int? updatedAt,
  }) {
    return AppTask(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      taskType: taskType,
      payload: payload,
      priority: priority,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries,
      depth: depth ?? this.depth,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      layerId: layerId ?? this.layerId,
      workerId: workerId ?? this.workerId,
      threadId: threadId ?? this.threadId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get priorityLabel {
    switch (priority) {
      case TaskPriority.high:
        return 'High';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.low:
        return 'Low';
    }
  }

  String get statusLabel {
    switch (status) {
      case TaskStatus.pending:
        return 'Pending';
      case TaskStatus.running:
        return 'Running';
      case TaskStatus.done:
        return 'Done';
      case TaskStatus.failed:
        return 'Failed';
    }
  }
}

class WorkerResult {
  const WorkerResult({
    required this.success,
    this.outputTasks = const [],
    this.error,
    this.metadata,
    this.layerName,
    this.workerName,
  });
  final bool success;
  final List<AppTask> outputTasks;
  final String? error;
  final Map<String, dynamic>? metadata;
  final String? layerName;
  final String? workerName;
}

class EvaluationResult {
  const EvaluationResult({
    required this.passed,
    required this.score,
    required this.reasons,
  });
  final bool passed;
  final double score;
  final List<String> reasons;
}
