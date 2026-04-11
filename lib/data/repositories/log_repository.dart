import 'package:gyeol/data/database/database.dart';

class LogRepository {
  LogRepository(this._db);
  final AppDatabase _db;

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

  Stream<List<ExecutionLog>> watchExecutionLogs({
    String? taskId,
    int limit = 200,
  }) {
    return _db.watchExecutionLogs(taskId: taskId, limit: limit);
  }
}
