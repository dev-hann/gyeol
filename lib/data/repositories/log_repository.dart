import 'package:gyeol/data/database/database.dart';

class LogRepository {
  LogRepository(this._db);
  final AppDatabase _db;

  Future<void> logExecution({
    required int taskId,
    required String status,
    int? workerId,
    String? message,
  }) {
    return _db.logExecution(
      taskId: taskId,
      workerId: workerId,
      status: status,
      message: message,
    );
  }

  Future<List<ExecutionLog>> listExecutionLogs({int? taskId, int limit = 200}) {
    return _db.listExecutionLogs(taskId: taskId, limit: limit);
  }

  Stream<List<ExecutionLog>> watchExecutionLogs({
    int? taskId,
    int limit = 200,
  }) {
    return _db.watchExecutionLogs(taskId: taskId, limit: limit);
  }

  Future<int> deleteOldLogs({int olderThanMs = 86400000}) {
    return _db.deleteOldExecutionLogs(olderThanMs: olderThanMs);
  }
}
