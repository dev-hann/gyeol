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
          id: 't1',
          taskType: 'parse',
          payload: '{}',
          priority: 'high',
          status: 'pending',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final task = await db.getTask('t1');
      expect(task, isNotNull);
      expect(task!.id, 't1');
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
          id: 't1',
          taskType: 'parse',
          payload: '{}',
          priority: 'high',
          status: 'pending',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await db.saveTask(
        TasksCompanion.insert(
          id: 't1',
          taskType: 'parse',
          payload: '{"v":2}',
          priority: 'high',
          status: 'running',
          createdAt: now,
          updatedAt: now + 1,
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
            id: 't$i',
            taskType: 'parse',
            payload: '{}',
            priority: 'low',
            status: 'pending',
            createdAt: ts,
            updatedAt: ts,
          ),
        );
      }

      final tasks = await db.listTasks();
      expect(tasks, hasLength(5));
      expect(tasks.first.id, 't4');
      expect(tasks.last.id, 't0');
    });

    test('listTasks respects limit and offset', () async {
      for (var i = 0; i < 5; i++) {
        final ts = (i + 1) * 1000;
        await db.saveTask(
          TasksCompanion.insert(
            id: 't$i',
            taskType: 'parse',
            payload: '{}',
            priority: 'low',
            status: 'pending',
            createdAt: ts,
            updatedAt: ts,
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
            id: 'p$i',
            taskType: 'parse',
            payload: '{}',
            priority: 'low',
            status: 'pending',
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
      await db.saveTask(
        TasksCompanion.insert(
          id: 'd1',
          taskType: 'parse',
          payload: '{}',
          priority: 'low',
          status: 'done',
          createdAt: now,
          updatedAt: now,
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
      expect(await db.getWorker('doomed'), isNotNull);

      await db.deleteWorker('doomed');
      expect(await db.getWorker('doomed'), isNull);
    });
  });

  group('execution log operations', () {
    test('logExecution inserts and listExecutionLogs retrieves', () async {
      await db.saveTask(
        TasksCompanion.insert(
          id: 't1',
          taskType: 'text',
          payload: '{}',
          priority: 'low',
          status: 'pending',
          createdAt: 0,
          updatedAt: 0,
        ),
      );
      await db.logExecution(
        taskId: 't1',
        workerName: 'w1',
        status: 'running',
        message: 'started',
      );

      final logs = await db.listExecutionLogs();
      expect(logs, hasLength(1));
      expect(logs.first.taskId, 't1');
      expect(logs.first.workerName, 'w1');
      expect(logs.first.status, 'running');
      expect(logs.first.message, 'started');
    });

    test('listExecutionLogs filters by taskId', () async {
      await db.saveTask(
        TasksCompanion.insert(
          id: 't1',
          taskType: 'text',
          payload: '{}',
          priority: 'low',
          status: 'pending',
          createdAt: 0,
          updatedAt: 0,
        ),
      );
      await db.saveTask(
        TasksCompanion.insert(
          id: 't2',
          taskType: 'text',
          payload: '{}',
          priority: 'low',
          status: 'pending',
          createdAt: 0,
          updatedAt: 0,
        ),
      );
      await db.logExecution(taskId: 't1', status: 'done');
      await db.logExecution(taskId: 't2', status: 'done');

      final filtered = await db.listExecutionLogs(taskId: 't1');
      expect(filtered, hasLength(1));
      expect(filtered.first.taskId, 't1');
    });

    test('listExecutionLogs respects limit', () async {
      for (var i = 0; i < 5; i++) {
        await db.saveTask(
          TasksCompanion.insert(
            id: 't$i',
            taskType: 'text',
            payload: '{}',
            priority: 'low',
            status: 'pending',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
      }
      for (var i = 0; i < 5; i++) {
        await db.logExecution(taskId: 't$i', status: 'ok');
      }

      final limited = await db.listExecutionLogs(limit: 3);
      expect(limited, hasLength(3));
    });

    test('listExecutionLogs ordered by createdAt desc', () async {
      for (var i = 0; i < 3; i++) {
        await db.saveTask(
          TasksCompanion.insert(
            id: 't$i',
            taskType: 'text',
            payload: '{}',
            priority: 'low',
            status: 'pending',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
      }
      for (var i = 0; i < 3; i++) {
        await db.logExecution(taskId: 't$i', status: 'ok');
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      final logs = await db.listExecutionLogs();
      expect(logs.first.taskId, 't2');
      expect(logs.last.taskId, 't0');
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
      await db.saveThreadLayerIds('thread1', [parseId, analyzeId]);

      final thread = await db.getThread('thread1');
      expect(thread, isNotNull);
      expect(thread!.name, 'thread1');
      expect(thread.path, '/path/to/file.dart');
      expect(thread.enabled, isTrue);
      expect(thread.status, 'idle');

      final threadLayers = await db.listThreadLayers('thread1');
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
      await db.saveThreadLayerIds('thread1', [aId]);
      await db.saveThread(
        ThreadsCompanion.insert(name: 'thread1', path: '/new/path'),
      );
      await db.saveThreadLayerIds('thread1', [bId]);

      final thread = await db.getThread('thread1');
      expect(thread!.path, '/new/path');

      final threadLayers = await db.listThreadLayers('thread1');
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
      await db.saveThreadLayerIds('doomed', [layerId]);
      expect(await db.getThread('doomed'), isNotNull);

      await db.deleteThread('doomed');
      expect(await db.getThread('doomed'), isNull);
      expect(await db.listThreadLayers('doomed'), isEmpty);
    });
  });
}
