import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/repositories/app_repository.dart';

void main() {
  late AppDatabase db;
  late AppRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = AppRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('TaskRepository createTask', () {
    test('stores task and returns id', () async {
      final id = await repo.tasks.createTask('summarize', {
        'text': 'hello',
      }, TaskPriority.high);

      expect(id, isNotEmpty);

      final task = await repo.tasks.getTask(id);
      expect(task, isNotNull);
      expect(task!.taskType, 'summarize');
      expect(task.payload, {'text': 'hello'});
      expect(task.priority, TaskPriority.high);
      expect(task.status, TaskStatus.pending);
      expect(task.retryCount, 0);
      expect(task.maxRetries, 3);
      expect(task.depth, 0);
      expect(task.parentTaskId, isNull);
      expect(task.layerName, isNull);
      expect(task.workerName, isNull);
    });

    test('stores task with null payload', () async {
      final id = await repo.tasks.createTask('ping', null, TaskPriority.low);

      final task = await repo.tasks.getTask(id);
      expect(task, isNotNull);
      expect(task!.payload, isNull);
    });

    test('stores task with list payload', () async {
      final id = await repo.tasks.createTask('batch', [
        'a',
        'b',
        'c',
      ], TaskPriority.medium);

      final task = await repo.tasks.getTask(id);
      expect(task!.payload, ['a', 'b', 'c']);
    });
  });

  group('TaskRepository getTask', () {
    test('returns null for non-existent id', () async {
      final task = await repo.tasks.getTask('nonexistent');
      expect(task, isNull);
    });
  });

  group('TaskRepository listTasks', () {
    test('returns empty list when no tasks', () async {
      final tasks = await repo.tasks.listTasks();
      expect(tasks, isEmpty);
    });

    test('returns all saved tasks', () async {
      await repo.tasks.createTask('a', null, TaskPriority.low);
      await repo.tasks.createTask('b', {'k': 'v'}, TaskPriority.high);
      await repo.tasks.createTask('c', [1, 2], TaskPriority.medium);

      final tasks = await repo.tasks.listTasks();
      expect(tasks, hasLength(3));
    });

    test('respects limit parameter', () async {
      for (var i = 0; i < 10; i++) {
        await repo.tasks.createTask('t$i', null, TaskPriority.low);
      }

      final tasks = await repo.tasks.listTasks(limit: 3);
      expect(tasks, hasLength(3));
    });
  });

  group('TaskRepository saveTask', () {
    test('updates existing task status and fields', () async {
      final id = await repo.tasks.createTask('parse', {
        'data': 'x',
      }, TaskPriority.high);
      var task = await repo.tasks.getTask(id);
      expect(task!.status, TaskStatus.pending);

      final updated = task.copyWith(
        status: TaskStatus.running,
        layerName: 'L1',
        workerName: 'w1',
      );
      await repo.tasks.saveTask(updated);

      task = await repo.tasks.getTask(id);
      expect(task!.status, TaskStatus.running);
      expect(task.layerName, 'L1');
      expect(task.workerName, 'w1');
      expect(task.taskType, 'parse');
      expect(task.priority, TaskPriority.high);
    });

    test('updates task to done status with retry count', () async {
      final id = await repo.tasks.createTask(
        'analyze',
        null,
        TaskPriority.medium,
      );

      var task = await repo.tasks.getTask(id);
      final updated = task!.copyWith(status: TaskStatus.done, retryCount: 2);
      await repo.tasks.saveTask(updated);

      task = await repo.tasks.getTask(id);
      expect(task!.status, TaskStatus.done);
      expect(task.retryCount, 2);
    });

    test('updates task with depth and parentTaskId', () async {
      final id = await repo.tasks.createTask('child', null, TaskPriority.low);

      var task = await repo.tasks.getTask(id);
      final updated = task!.copyWith(depth: 3, parentTaskId: 'parent-123');
      await repo.tasks.saveTask(updated);

      task = await repo.tasks.getTask(id);
      expect(task!.depth, 3);
      expect(task.parentTaskId, 'parent-123');
    });

    test('preserves payload through update', () async {
      final id = await repo.tasks.createTask('x', {
        'key': 'value',
        'count': 42,
      }, TaskPriority.high);

      var task = await repo.tasks.getTask(id);
      await repo.tasks.saveTask(task!.copyWith(status: TaskStatus.running));

      task = await repo.tasks.getTask(id);
      expect(task!.payload, {'key': 'value', 'count': 42});
    });
  });

  group('TaskRepository getQueueSize', () {
    test('returns 0 when no tasks', () async {
      final size = await repo.tasks.getQueueSize();
      expect(size, 0);
    });

    test('counts pending tasks', () async {
      await repo.tasks.createTask('a', null, TaskPriority.high);
      await repo.tasks.createTask('b', null, TaskPriority.low);

      final size = await repo.tasks.getQueueSize();
      expect(size, 2);
    });
  });

  group('TaskRepository full lifecycle', () {
    test('create → run → complete flow', () async {
      final id = await repo.tasks.createTask('lifecycle', {
        'input': 'data',
      }, TaskPriority.high);

      var task = await repo.tasks.getTask(id);
      expect(task!.status, TaskStatus.pending);

      await repo.tasks.saveTask(task.copyWith(status: TaskStatus.running));
      task = await repo.tasks.getTask(id);
      expect(task!.status, TaskStatus.running);

      await repo.tasks.saveTask(task.copyWith(status: TaskStatus.done));
      task = await repo.tasks.getTask(id);
      expect(task!.status, TaskStatus.done);
    });

    test('create → run → fail with retry', () async {
      final id = await repo.tasks.createTask(
        'retry_test',
        null,
        TaskPriority.medium,
      );

      var task = await repo.tasks.getTask(id);
      await repo.tasks.saveTask(
        task!.copyWith(status: TaskStatus.running, workerName: 'w1'),
      );

      task = await repo.tasks.getTask(id);
      await repo.tasks.saveTask(
        task!.copyWith(status: TaskStatus.failed, retryCount: 1),
      );

      task = await repo.tasks.getTask(id);
      expect(task!.status, TaskStatus.failed);
      expect(task.retryCount, 1);
      expect(task.workerName, 'w1');
    });
  });
}
