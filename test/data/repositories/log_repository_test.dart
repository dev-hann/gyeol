import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/repositories/app_repository.dart';

void main() {
  late AppDatabase db;
  late LogRepository logs;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    logs = AppRepository(db).logs;
  });

  tearDown(() async {
    await db.close();
  });

  group('logExecution', () {
    test('inserts an execution log and retrieves it', () async {
      await logs.logExecution(
        taskId: 't1',
        status: 'running',
        workerName: 'worker-a',
        message: 'Started processing',
      );

      final result = await logs.listExecutionLogs();
      expect(result, hasLength(1));
      expect(result.first.taskId, 't1');
      expect(result.first.status, 'running');
      expect(result.first.workerName, 'worker-a');
      expect(result.first.message, 'Started processing');
    });

    test('stores log without optional fields', () async {
      await logs.logExecution(taskId: 't2', status: 'done');

      final result = await logs.listExecutionLogs();
      expect(result, hasLength(1));
      expect(result.first.taskId, 't2');
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
      await logs.logExecution(taskId: 't1', status: 'running');
      await logs.logExecution(taskId: 't2', status: 'done');
      await logs.logExecution(taskId: 't1', status: 'done');

      final result = await logs.listExecutionLogs(taskId: 't1');
      expect(result, hasLength(2));
      expect(result.every((l) => l.taskId == 't1'), isTrue);
    });

    test('respects limit parameter', () async {
      for (var i = 0; i < 5; i++) {
        await logs.logExecution(taskId: 'batch', status: 'ok');
      }

      final result = await logs.listExecutionLogs(limit: 3);
      expect(result, hasLength(3));
    });

    test('returns logs ordered by createdAt descending', () async {
      await logs.logExecution(
        taskId: 'first',
        status: 'done',
        message: 'earliest',
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await logs.logExecution(
        taskId: 'second',
        status: 'done',
        message: 'latest',
      );

      final result = await logs.listExecutionLogs();
      expect(result.first.taskId, 'second');
      expect(result.last.taskId, 'first');
    });
  });

  group('watchExecutionLogs', () {
    test('emits updates when new logs are inserted', () async {
      final stream = logs.watchExecutionLogs();

      final emitted = <List<ExecutionLog>>[];
      stream.listen(emitted.add);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await logs.logExecution(taskId: 'w1', status: 'running');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(emitted, isNotEmpty);
      expect(emitted.last, hasLength(1));
      expect(emitted.last.first.taskId, 'w1');
    });
  });
}
