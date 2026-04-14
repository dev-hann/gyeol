import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/repositories/app_repository.dart';

void main() {  Future<int> _createThread(AppDatabase database) async {
    await database.saveThread(ThreadsCompanion.insert(name: 'default', path: '/tmp'));
    return (await database.getThread('default'))!.id;
  }

  late AppDatabase db;
  late AppRepository repo;

  late int _tid;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    _tid = await _createThread(db);
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

      expect(id, isA<int>());

      final tasks = await repo.tasks.listTasks();
      final task = tasks.firstWhere((t) => t.taskType == 'summarize');
      expect(task, isNotNull);
      expect(task.taskType, 'summarize');
      expect(task.payload, {'text': 'hello'});
      expect(task.priority, TaskPriority.high);
      expect(task.status, TaskStatus.pending);
      expect(task.retryCount, 0);
      expect(task.maxRetries, 3);
      expect(task.depth, 0);
      expect(task.parentTaskId, isNull);
      expect(task.layerId, isNull);
      expect(task.workerId, isNull);
    });

    test('stores task with null payload', () async {
      await repo.tasks.createTask('ping', null, TaskPriority.low);

      final tasks = await repo.tasks.listTasks();
      final task = tasks.firstWhere((t) => t.taskType == 'ping');
      expect(task, isNotNull);
      expect(task.payload, isNull);
    });

    test('stores task with list payload', () async {
      await repo.tasks.createTask('batch', [
        'a',
        'b',
        'c',
      ], TaskPriority.medium);

      final tasks = await repo.tasks.listTasks();
      final task = tasks.firstWhere((t) => t.taskType == 'batch');
      expect(task.payload, ['a', 'b', 'c']);
    });
  });

  group('TaskRepository getTask', () {
    test('returns null for non-existent uuid', () async {
      final task = await repo.tasks.getTask('nonexistent-uuid');
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
      await repo.layers.saveLayer(
        LayerDefinition(
          id: 0,
threadId: _tid,
        name: 'L1',
          inputTypes: ['text'],
          outputTypes: [],
        ),
      );
      final layers = await repo.layers.listLayers();
      final layerId = layers.first.id;
      await repo.workers.saveWorker(
        WorkerDefinition(
          id: 0,
          name: 'w1',
          layerId: layerId,
          systemPrompt: 'test',
        ),
      );
      await repo.tasks.createTask('parse', {'data': 'x'}, TaskPriority.high);
      var tasks = await repo.tasks.listTasks();
      var task = tasks.firstWhere((t) => t.taskType == 'parse');
      expect(task.status, TaskStatus.pending);

      final worker = await repo.workers.getWorker('w1');
      final updated = task.copyWith(
        status: TaskStatus.running,
        layerId: layerId,
        workerId: worker!.id,
      );
      await repo.tasks.saveTask(updated);

      tasks = await repo.tasks.listTasks();
      task = tasks.firstWhere((t) => t.taskType == 'parse');
      expect(task.status, TaskStatus.running);
      expect(task.layerId, layerId);
      expect(task.workerId, worker.id);
      expect(task.taskType, 'parse');
      expect(task.priority, TaskPriority.high);
    });

    test('updates task to done status with retry count', () async {
      await repo.tasks.createTask('analyze', null, TaskPriority.medium);

      var tasks = await repo.tasks.listTasks();
      var task = tasks.firstWhere((t) => t.taskType == 'analyze');
      final updated = task.copyWith(status: TaskStatus.done, retryCount: 2);
      await repo.tasks.saveTask(updated);

      tasks = await repo.tasks.listTasks();
      task = tasks.firstWhere((t) => t.taskType == 'analyze');
      expect(task.status, TaskStatus.done);
      expect(task.retryCount, 2);
    });

    test('updates task with depth and parentTaskId', () async {
      await repo.tasks.createTask('parent', null, TaskPriority.low);
      await repo.tasks.createTask('child', null, TaskPriority.low);

      var tasks = await repo.tasks.listTasks();
      final parentTask = tasks.firstWhere((t) => t.taskType == 'parent');
      var childTask = tasks.firstWhere((t) => t.taskType == 'child');
      final updated = childTask.copyWith(depth: 3, parentTaskId: parentTask.id);
      await repo.tasks.saveTask(updated);

      tasks = await repo.tasks.listTasks();
      childTask = tasks.firstWhere((t) => t.taskType == 'child');
      expect(childTask.depth, 3);
      expect(childTask.parentTaskId, parentTask.id);
    });

    test('preserves payload through update', () async {
      await repo.tasks.createTask('x', {
        'key': 'value',
        'count': 42,
      }, TaskPriority.high);

      var tasks = await repo.tasks.listTasks();
      var task = tasks.firstWhere((t) => t.taskType == 'x');
      await repo.tasks.saveTask(task.copyWith(status: TaskStatus.running));

      tasks = await repo.tasks.listTasks();
      task = tasks.firstWhere((t) => t.taskType == 'x');
      expect(task.payload, {'key': 'value', 'count': 42});
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
    test('create -> run -> complete flow', () async {
      await repo.tasks.createTask('lifecycle', {
        'input': 'data',
      }, TaskPriority.high);

      var tasks = await repo.tasks.listTasks();
      var task = tasks.firstWhere((t) => t.taskType == 'lifecycle');
      expect(task.status, TaskStatus.pending);

      await repo.tasks.saveTask(task.copyWith(status: TaskStatus.running));
      tasks = await repo.tasks.listTasks();
      task = tasks.firstWhere((t) => t.taskType == 'lifecycle');
      expect(task.status, TaskStatus.running);

      await repo.tasks.saveTask(task.copyWith(status: TaskStatus.done));
      tasks = await repo.tasks.listTasks();
      task = tasks.firstWhere((t) => t.taskType == 'lifecycle');
      expect(task.status, TaskStatus.done);
    });

    test('create -> run -> fail with retry', () async {
      await repo.layers.saveLayer(
        LayerDefinition(
          id: 0,
threadId: _tid,
        name: 'L1',
          inputTypes: ['text'],
          outputTypes: [],
        ),
      );
      final layers = await repo.layers.listLayers();
      final layerId = layers.first.id;
      await repo.workers.saveWorker(
        WorkerDefinition(
          id: 0,
          name: 'w1',
          layerId: layerId,
          systemPrompt: 'test',
        ),
      );
      await repo.tasks.createTask('retry_test', null, TaskPriority.medium);

      var tasks = await repo.tasks.listTasks();
      var task = tasks.firstWhere((t) => t.taskType == 'retry_test');
      final worker = await repo.workers.getWorker('w1');
      await repo.tasks.saveTask(
        task.copyWith(status: TaskStatus.running, workerId: worker!.id),
      );

      tasks = await repo.tasks.listTasks();
      task = tasks.firstWhere((t) => t.taskType == 'retry_test');
      await repo.tasks.saveTask(
        task.copyWith(status: TaskStatus.failed, retryCount: 1),
      );

      tasks = await repo.tasks.listTasks();
      task = tasks.firstWhere((t) => t.taskType == 'retry_test');
      expect(task.status, TaskStatus.failed);
      expect(task.retryCount, 1);
      expect(task.workerId, worker.id);
    });
  });

  group('TaskRepository malformed data resilience', () {
    test('returns null payload when stored JSON is malformed', () async {
      await db
          .into(db.tasks)
          .insert(
            TasksCompanion.insert(
              uuid: 'malformed-uuid',
              taskType: 'broken',
              payload: 'not-valid-json{{{',
              priority: 'low',
              status: 'pending',
            ),
          );

      final tasks = await repo.tasks.listTasks();
      expect(tasks, hasLength(1));
      expect(tasks.first.uuid, 'malformed-uuid');
      expect(tasks.first.payload, isNull);
    });

    test('returns null payload when stored JSON is truncated', () async {
      await db
          .into(db.tasks)
          .insert(
            TasksCompanion.insert(
              uuid: 'truncated-uuid',
              taskType: 'truncated',
              payload: '{"key":',
              priority: 'medium',
              status: 'running',
            ),
          );

      final tasks = await repo.tasks.listTasks();
      expect(tasks, hasLength(1));
      expect(tasks.first.payload, isNull);
    });

    test('getTask returns null payload for malformed row', () async {
      await db
          .into(db.tasks)
          .insert(
            TasksCompanion.insert(
              uuid: 'get-bad-uuid',
              taskType: 'test',
              payload: 'broken',
              priority: 'high',
              status: 'done',
            ),
          );

      final task = await repo.tasks.getTask('get-bad-uuid');
      expect(task, isNotNull);
      expect(task!.payload, isNull);
    });

    test(
      'handles payload that is valid JSON but wrong type (number)',
      () async {
        await db
            .into(db.tasks)
            .insert(
              TasksCompanion.insert(
                uuid: 'number-payload',
                taskType: 'numtest',
                payload: '42',
                priority: 'low',
                status: 'pending',
              ),
            );

        final tasks = await repo.tasks.listTasks();
        expect(tasks, hasLength(1));
        expect(tasks.first.payload, 42);
      },
    );

    test(
      'handles payload that is valid JSON but wrong type (boolean)',
      () async {
        await db
            .into(db.tasks)
            .insert(
              TasksCompanion.insert(
                uuid: 'bool-payload',
                taskType: 'booltest',
                payload: 'true',
                priority: 'low',
                status: 'pending',
              ),
            );

        final tasks = await repo.tasks.listTasks();
        expect(tasks, hasLength(1));
        expect(tasks.first.payload, true);
      },
    );
  });
}
