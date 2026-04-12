import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/database/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('task operations', () {
    test('saveTask inserts and getTask retrieves', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.saveTask(
        TasksCompanion.insert(
          uuid: 't1',
          taskType: 'parse',
          payload: '{}',
          priority: 'high',
          status: 'pending',
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      final task = await db.getTask('t1');
      expect(task, isNotNull);
      expect(task!.uuid, 't1');
      expect(task.taskType, 'parse');
      expect(task.status, 'pending');
    });

    test('getTask returns null for missing id', () async {
      final task = await db.getTask('nonexistent');
      expect(task, isNull);
    });

    test('saveTask upserts on conflict', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.saveTask(
        TasksCompanion.insert(
          uuid: 't1',
          taskType: 'parse',
          payload: '{}',
          priority: 'high',
          status: 'pending',
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      final existing = await db.getTask('t1');
      await db.saveTask(
        TasksCompanion(
          id: Value(existing!.id),
          uuid: const Value('t1'),
          taskType: const Value('parse'),
          payload: const Value('{"v":2}'),
          priority: const Value('high'),
          status: const Value('running'),
          createdAt: Value(now),
          updatedAt: Value(now + 1),
        ),
      );

      final task = await db.getTask('t1');
      expect(task!.status, 'running');
      expect(task.payload, '{"v":2}');
    });

    test('listTasks returns tasks ordered by createdAt desc', () async {
      for (var i = 0; i < 5; i++) {
        final ts = (i + 1) * 1000;
        await db.saveTask(
          TasksCompanion.insert(
            uuid: 't$i',
            taskType: 'parse',
            payload: '{}',
            priority: 'low',
            status: 'pending',
            createdAt: Value(ts),
            updatedAt: Value(ts),
          ),
        );
      }

      final tasks = await db.listTasks();
      expect(tasks, hasLength(5));
      expect(tasks.first.uuid, 't4');
      expect(tasks.last.uuid, 't0');
    });

    test('listTasks respects limit and offset', () async {
      for (var i = 0; i < 5; i++) {
        final ts = (i + 1) * 1000;
        await db.saveTask(
          TasksCompanion.insert(
            uuid: 't$i',
            taskType: 'parse',
            payload: '{}',
            priority: 'low',
            status: 'pending',
            createdAt: Value(ts),
            updatedAt: Value(ts),
          ),
        );
      }

      final page = await db.listTasks(limit: 2, offset: 2);
      expect(page, hasLength(2));
    });
  });

  group('getQueueSize', () {
    test('returns 0 when no pending tasks', () async {
      expect(await db.getQueueSize(), 0);
    });

    test('counts only pending tasks', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      for (var i = 0; i < 3; i++) {
        await db.saveTask(
          TasksCompanion.insert(
            uuid: 'p$i',
            taskType: 'parse',
            payload: '{}',
            priority: 'low',
            status: 'pending',
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
      }
      await db.saveTask(
        TasksCompanion.insert(
          uuid: 'd1',
          taskType: 'parse',
          payload: '{}',
          priority: 'low',
          status: 'done',
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      expect(await db.getQueueSize(), 3);
    });
  });

  group('settings operations', () {
    test('saveSettings and getSettingsJson round-trip', () async {
      const json = '{"provider":"openai","model":"gpt-4"}';
      await db.saveSettings(json);

      expect(await db.getSettingsJson(), json);
    });

    test('getSettingsJson returns null when no settings', () async {
      expect(await db.getSettingsJson(), isNull);
    });

    test('saveSettings upserts', () async {
      await db.saveSettings('v1');
      await db.saveSettings('v2');

      expect(await db.getSettingsJson(), 'v2');
    });
  });

  group('worker operations', () {
    test('saveWorker inserts and getWorker retrieves', () async {
      await db.saveLayer(
        LayersCompanion.insert(
          name: 'parse',
          inputTypes: '[]',
          outputTypes: '[]',
        ),
      );
      final layers = await db.listLayers();
      final layerId = layers.first.id;
      await db.saveWorker(
        WorkersCompanion.insert(
          name: 'parser',
          layerId: layerId,
          systemPrompt: 'Parse text',
          enabled: const Value(true),
        ),
      );

      final worker = await db.getWorker('parser');
      expect(worker, isNotNull);
      expect(worker!.name, 'parser');
      expect(worker.layerId, layerId);
      expect(worker.systemPrompt, 'Parse text');
    });

    test('getWorker returns null for missing name', () async {
      expect(await db.getWorker('ghost'), isNull);
    });

    test('listWorkers returns all workers', () async {
      await db.saveLayer(
        LayersCompanion.insert(name: 'l1', inputTypes: '[]', outputTypes: '[]'),
      );
      await db.saveLayer(
        LayersCompanion.insert(name: 'l2', inputTypes: '[]', outputTypes: '[]'),
      );
      final layers = await db.listLayers();
      final l1Id = layers.firstWhere((l) => l.name == 'l1').id;
      final l2Id = layers.firstWhere((l) => l.name == 'l2').id;
      await db.saveWorker(
        WorkersCompanion.insert(name: 'a', layerId: l1Id, systemPrompt: 'p1'),
      );
      await db.saveWorker(
        WorkersCompanion.insert(name: 'b', layerId: l2Id, systemPrompt: 'p2'),
      );

      final workers = await db.listWorkers();
      expect(workers, hasLength(2));
    });

    test('deleteWorker removes worker', () async {
      await db.saveLayer(
        LayersCompanion.insert(name: 'l', inputTypes: '[]', outputTypes: '[]'),
      );
      final layers = await db.listLayers();
      final layerId = layers.first.id;
      await db.saveWorker(
        WorkersCompanion.insert(
          name: 'doomed',
          layerId: layerId,
          systemPrompt: 'p',
        ),
      );
      final worker = await db.getWorker('doomed');
      expect(worker, isNotNull);

      await db.deleteWorker(worker!.id);
      expect(await db.getWorker('doomed'), isNull);
    });
  });

  group('execution log operations', () {
    Future<int> insertTask(String uuid) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.saveTask(
        TasksCompanion.insert(
          uuid: uuid,
          taskType: 'text',
          payload: '{}',
          priority: 'low',
          status: 'pending',
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      return (await db.getTask(uuid))!.id;
    }

    test('logExecution inserts and listExecutionLogs retrieves', () async {
      final taskId = await insertTask('t1');
      await db.logExecution(
        taskId: taskId,
        workerId: 1,
        status: 'running',
        message: 'started',
      );

      final logs = await db.listExecutionLogs();
      expect(logs, hasLength(1));
      expect(logs.first.taskId, taskId);
      expect(logs.first.workerId, 1);
      expect(logs.first.status, 'running');
      expect(logs.first.message, 'started');
    });

    test('listExecutionLogs filters by taskId', () async {
      final t1 = await insertTask('t1');
      final t2 = await insertTask('t2');
      await db.logExecution(taskId: t1, status: 'done');
      await db.logExecution(taskId: t2, status: 'done');

      final filtered = await db.listExecutionLogs(taskId: t1);
      expect(filtered, hasLength(1));
      expect(filtered.first.taskId, t1);
    });

    test('listExecutionLogs respects limit', () async {
      for (var i = 0; i < 5; i++) {
        final tId = await insertTask('t$i');
        await db.logExecution(taskId: tId, status: 'ok');
      }

      final limited = await db.listExecutionLogs(limit: 3);
      expect(limited, hasLength(3));
    });

    test('listExecutionLogs ordered by createdAt desc', () async {
      final ids = <int>[];
      for (var i = 0; i < 3; i++) {
        ids.add(await insertTask('t$i'));
      }
      for (var i = 0; i < 3; i++) {
        await db.logExecution(taskId: ids[i], status: 'ok');
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      final logs = await db.listExecutionLogs();
      expect(logs.first.taskId, ids[2]);
      expect(logs.last.taskId, ids[0]);
    });
  });

  group('layer operations', () {
    test('saveLayer and listLayers round-trip', () async {
      await db.saveLayer(
        LayersCompanion.insert(
          name: 'parse',
          inputTypes: '["raw"]',
          outputTypes: '["parsed"]',
        ),
      );

      final layers = await db.listLayers();
      expect(layers, hasLength(1));
      expect(layers.first.name, 'parse');
    });

    test('deleteLayer removes layer', () async {
      await db.saveLayer(
        LayersCompanion.insert(
          name: 'gone',
          inputTypes: '[]',
          outputTypes: '[]',
        ),
      );

      final layers = await db.listLayers();
      await db.deleteLayer(layers.first.id);
      expect(await db.listLayers(), isEmpty);
    });
  });

  group('thread operations', () {
    test('saveThread inserts and getThread retrieves', () async {
      await db.saveLayer(
        LayersCompanion.insert(
          name: 'parse',
          inputTypes: '[]',
          outputTypes: '[]',
        ),
      );
      await db.saveLayer(
        LayersCompanion.insert(
          name: 'analyze',
          inputTypes: '[]',
          outputTypes: '[]',
        ),
      );
      final layers = await db.listLayers();
      final parseId = layers.firstWhere((l) => l.name == 'parse').id;
      final analyzeId = layers.firstWhere((l) => l.name == 'analyze').id;
      await db.saveThread(
        ThreadsCompanion.insert(name: 'thread1', path: '/path/to/file.dart'),
      );
      final thread = await db.getThread('thread1');
      await db.saveThreadLayerIds(thread!.id, [parseId, analyzeId]);

      expect(thread, isNotNull);
      expect(thread.name, 'thread1');
      expect(thread.path, '/path/to/file.dart');
      expect(thread.enabled, isTrue);
      expect(thread.status, 'idle');

      final threadLayers = await db.listThreadLayers(thread.id);
      expect(threadLayers, hasLength(2));
      expect(threadLayers[0].layerId, parseId);
      expect(threadLayers[1].layerId, analyzeId);
    });

    test('getThread returns null for missing name', () async {
      expect(await db.getThread('nonexistent'), isNull);
    });

    test('saveThread upserts on conflict', () async {
      await db.saveLayer(
        LayersCompanion.insert(name: 'a', inputTypes: '[]', outputTypes: '[]'),
      );
      await db.saveLayer(
        LayersCompanion.insert(name: 'b', inputTypes: '[]', outputTypes: '[]'),
      );
      final layers = await db.listLayers();
      final aId = layers.firstWhere((l) => l.name == 'a').id;
      final bId = layers.firstWhere((l) => l.name == 'b').id;
      await db.saveThread(
        ThreadsCompanion.insert(name: 'thread1', path: '/old/path'),
      );
      var thread = await db.getThread('thread1');
      await db.saveThreadLayerIds(thread!.id, [aId]);
      await db.saveThread(
        ThreadsCompanion(
          id: Value(thread.id),
          name: const Value('thread1'),
          path: const Value('/new/path'),
        ),
      );
      thread = await db.getThread('thread1');
      await db.saveThreadLayerIds(thread!.id, [bId]);

      expect(thread.path, '/new/path');

      final threadLayers = await db.listThreadLayers(thread.id);
      expect(threadLayers, hasLength(1));
      expect(threadLayers[0].layerId, bId);
    });

    test('listThreads returns all threads', () async {
      await db.saveThread(ThreadsCompanion.insert(name: 'a', path: '/a'));
      await db.saveThread(ThreadsCompanion.insert(name: 'b', path: '/b'));

      final threads = await db.listThreads();
      expect(threads, hasLength(2));
    });

    test('deleteThread removes thread and layers', () async {
      await db.saveLayer(
        LayersCompanion.insert(name: 'L1', inputTypes: '[]', outputTypes: '[]'),
      );
      final layers = await db.listLayers();
      final layerId = layers.first.id;
      await db.saveThread(ThreadsCompanion.insert(name: 'doomed', path: '/x'));
      final thread = await db.getThread('doomed');
      await db.saveThreadLayerIds(thread!.id, [layerId]);
      expect(await db.getThread('doomed'), isNotNull);

      await db.deleteThread(thread.id);
      expect(await db.getThread('doomed'), isNull);
      expect(await db.listThreadLayers(thread.id), isEmpty);
    });
  });
}
