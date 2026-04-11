import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/repositories/app_repository.dart';

void main() {
  late AppDatabase db;
  late AppRepository repo;
  late LogRepository logs;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = AppRepository(db);
    logs = repo.logs;
  });

  tearDown(() async {
    await db.close();
  });

  group('logExecution', () {
    test('inserts an execution log and retrieves it', () async {
      final taskId = await repo.tasks.createTask(
        'test',
        null,
        TaskPriority.low,
      );
      await logs.logExecution(
        taskId: taskId,
        status: 'running',
        workerName: 'worker-a',
        message: 'Started processing',
      );

      final result = await logs.listExecutionLogs();
      expect(result, hasLength(1));
      expect(result.first.taskId, taskId);
      expect(result.first.status, 'running');
      expect(result.first.workerName, 'worker-a');
      expect(result.first.message, 'Started processing');
    });

    test('stores log without optional fields', () async {
      final taskId = await repo.tasks.createTask(
        'test',
        null,
        TaskPriority.low,
      );
      await logs.logExecution(taskId: taskId, status: 'done');

      final result = await logs.listExecutionLogs();
      expect(result, hasLength(1));
      expect(result.first.taskId, taskId);
      expect(result.first.status, 'done');
      expect(result.first.workerName, isNull);
      expect(result.first.message, isNull);
    });
  });

  group('listExecutionLogs', () {
    test('returns empty list when no logs exist', () async {
      final result = await logs.listExecutionLogs();
      expect(result, isEmpty);
    });

    test('filters by taskId', () async {
      final t1 = await repo.tasks.createTask('test', null, TaskPriority.low);
      final t2 = await repo.tasks.createTask('test', null, TaskPriority.low);
      await logs.logExecution(taskId: t1, status: 'running');
      await logs.logExecution(taskId: t2, status: 'done');
      await logs.logExecution(taskId: t1, status: 'done');

      final result = await logs.listExecutionLogs(taskId: t1);
      expect(result, hasLength(2));
      expect(result.every((l) => l.taskId == t1), isTrue);
    });

    test('respects limit parameter', () async {
      final taskId = await repo.tasks.createTask(
        'test',
        null,
        TaskPriority.low,
      );
      for (var i = 0; i < 5; i++) {
        await logs.logExecution(taskId: taskId, status: 'ok');
      }

      final result = await logs.listExecutionLogs(limit: 3);
      expect(result, hasLength(3));
    });

    test('returns logs ordered by createdAt descending', () async {
      final first = await repo.tasks.createTask('test', null, TaskPriority.low);
      final second = await repo.tasks.createTask(
        'test',
        null,
        TaskPriority.low,
      );
      await logs.logExecution(
        taskId: first,
        status: 'done',
        message: 'earliest',
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await logs.logExecution(
        taskId: second,
        status: 'done',
        message: 'latest',
      );

      final result = await logs.listExecutionLogs();
      expect(result.first.taskId, second);
      expect(result.last.taskId, first);
    });
  });

  group('watchExecutionLogs', () {
    test('emits updates when new logs are inserted', () async {
      final taskId = await repo.tasks.createTask(
        'test',
        null,
        TaskPriority.low,
      );
      final stream = logs.watchExecutionLogs();

      final emitted = <List<ExecutionLog>>[];
      stream.listen(emitted.add);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await logs.logExecution(taskId: taskId, status: 'running');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(emitted, isNotEmpty);
      expect(emitted.last, hasLength(1));
      expect(emitted.last.first.taskId, taskId);
    });
  });
}
