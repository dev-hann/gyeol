import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/repositories/app_repository.dart';
import 'package:gyeol/engine/chat/tool_registry.dart';

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

  group('ToolRegistry.executeTool', () {
    test('unknown tool returns error json', () async {
      final result = await ToolRegistry.executeTool(
        'nonexistent_tool',
        {},
        repo,
      );
      final decoded = jsonDecode(result) as Map<String, dynamic>;
      expect(decoded['error'], contains('Unknown tool'));
    });

    group('create_layer', () {
      test('creates a layer and returns success', () async {
        final result = await ToolRegistry.executeTool('create_layer', {
          'name': 'Parser',
          'inputTypes': ['text'],
          'outputTypes': ['tokens'],
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['success'], true);

        final layers = await repo.layers.listLayers();
        expect(layers, hasLength(1));
        expect(layers.first.name, 'Parser');
        expect(layers.first.inputTypes, ['text']);
        expect(layers.first.outputTypes, ['tokens']);
      });
    });

    group('list_layers', () {
      test('returns empty list when no layers', () async {
        final result = await ToolRegistry.executeTool('list_layers', {}, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['layers'], isEmpty);
      });

      test('returns created layers with worker names', () async {
        await repo.layers.saveLayer(
          const LayerDefinition(
            name: 'L1',
            inputTypes: ['text'],
            outputTypes: ['analysis'],
          ),
        );
        await repo.workers.saveWorker(
          const WorkerDefinition(
            name: 'W1',
            layerName: 'L1',
            systemPrompt: 'parse',
          ),
        );

        final result = await ToolRegistry.executeTool('list_layers', {}, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        final layers = (decoded['layers'] as List).cast<Map<String, dynamic>>();
        expect(layers, hasLength(1));
        expect(layers.first['name'], 'L1');
        expect(layers.first['workerNames'], ['W1']);
      });
    });

    group('update_layer', () {
      test('returns error when layer not found', () async {
        final result = await ToolRegistry.executeTool('update_layer', {
          'name': 'missing',
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], isNotNull);
      });

      test('updates existing layer', () async {
        await repo.layers.saveLayer(
          const LayerDefinition(
            name: 'L1',
            inputTypes: ['text'],
            outputTypes: ['tokens'],
          ),
        );

        final result = await ToolRegistry.executeTool('update_layer', {
          'name': 'L1',
          'layerPrompt': 'Extract key clauses',
          'enabled': false,
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['success'], true);

        final layers = await repo.layers.listLayers();
        expect(layers.first.layerPrompt, 'Extract key clauses');
        expect(layers.first.enabled, false);
      });
    });

    group('delete_layer', () {
      test('deletes a layer by name', () async {
        await repo.layers.saveLayer(
          const LayerDefinition(
            name: 'L1',
            inputTypes: ['a'],
            outputTypes: ['b'],
          ),
        );

        final result = await ToolRegistry.executeTool('delete_layer', {
          'name': 'L1',
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['success'], true);

        final layers = await repo.layers.listLayers();
        expect(layers, isEmpty);
      });
    });

    group('create_worker', () {
      test('creates a worker and returns success', () async {
        await repo.layers.saveLayer(
          const LayerDefinition(name: 'L1', inputTypes: [], outputTypes: []),
        );
        final result = await ToolRegistry.executeTool('create_worker', {
          'name': 'W1',
          'layerName': 'L1',
          'systemPrompt': 'You are a parser',
          'model': 'gpt-4',
          'temperature': 0.5,
          'maxTokens': 2048,
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['success'], true);

        final worker = await repo.workers.getWorker('W1');
        expect(worker, isNotNull);
        expect(worker!.layerName, 'L1');
        expect(worker.systemPrompt, 'You are a parser');
        expect(worker.model, 'gpt-4');
        expect(worker.temperature, 0.5);
        expect(worker.maxTokens, 2048);
      });
    });

    group('list_workers', () {
      test('returns workers filtered by layerName', () async {
        await repo.layers.saveLayer(
          const LayerDefinition(name: 'L1', inputTypes: [], outputTypes: []),
        );
        await repo.layers.saveLayer(
          const LayerDefinition(name: 'L2', inputTypes: [], outputTypes: []),
        );
        await repo.workers.saveWorker(
          const WorkerDefinition(
            name: 'W1',
            layerName: 'L1',
            systemPrompt: 'p1',
          ),
        );
        await repo.workers.saveWorker(
          const WorkerDefinition(
            name: 'W2',
            layerName: 'L2',
            systemPrompt: 'p2',
          ),
        );

        final result = await ToolRegistry.executeTool('list_workers', {
          'layerName': 'L1',
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        final workers = (decoded['workers'] as List)
            .cast<Map<String, dynamic>>();
        expect(workers, hasLength(1));
        expect(workers.first['name'], 'W1');
      });
    });

    group('update_worker', () {
      test('returns error when worker not found', () async {
        final result = await ToolRegistry.executeTool('update_worker', {
          'name': 'ghost',
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], isNotNull);
      });

      test('updates existing worker', () async {
        await repo.layers.saveLayer(
          const LayerDefinition(name: 'L1', inputTypes: [], outputTypes: []),
        );
        await repo.workers.saveWorker(
          const WorkerDefinition(
            name: 'W1',
            layerName: 'L1',
            systemPrompt: 'old',
          ),
        );

        await ToolRegistry.executeTool('update_worker', {
          'name': 'W1',
          'systemPrompt': 'new prompt',
          'enabled': false,
        }, repo);

        final worker = await repo.workers.getWorker('W1');
        expect(worker!.systemPrompt, 'new prompt');
        expect(worker.enabled, false);
      });
    });

    group('delete_worker', () {
      test('deletes a worker by name', () async {
        await repo.layers.saveLayer(
          const LayerDefinition(name: 'L1', inputTypes: [], outputTypes: []),
        );
        await repo.workers.saveWorker(
          const WorkerDefinition(
            name: 'W1',
            layerName: 'L1',
            systemPrompt: 'p',
          ),
        );

        final result = await ToolRegistry.executeTool('delete_worker', {
          'name': 'W1',
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['success'], true);

        final worker = await repo.workers.getWorker('W1');
        expect(worker, isNull);
      });
    });

    group('create_thread', () {
      test('creates a thread and returns success', () async {
        await repo.layers.saveLayer(
          const LayerDefinition(name: 'L1', inputTypes: [], outputTypes: []),
        );
        await repo.layers.saveLayer(
          const LayerDefinition(name: 'L2', inputTypes: [], outputTypes: []),
        );
        final result = await ToolRegistry.executeTool('create_thread', {
          'name': 'T1',
          'path': '/home/user/project',
          'layerNames': ['L1', 'L2'],
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['success'], true);

        final thread = await repo.threads.getThread('T1');
        expect(thread, isNotNull);
        expect(thread!.path, '/home/user/project');
        expect(thread.layerNames, ['L1', 'L2']);
      });
    });

    group('list_threads', () {
      test('returns all threads', () async {
        await repo.layers.saveLayer(
          const LayerDefinition(name: 'L1', inputTypes: [], outputTypes: []),
        );
        await repo.threads.saveThread(
          const ThreadDefinition(name: 'T1', path: '/a', layerNames: ['L1']),
        );

        final result = await ToolRegistry.executeTool('list_threads', {}, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        final threads = (decoded['threads'] as List)
            .cast<Map<String, dynamic>>();
        expect(threads, hasLength(1));
        expect(threads.first['name'], 'T1');
        expect(threads.first['status'], 'idle');
      });
    });

    group('run_thread', () {
      test('returns error when thread not found', () async {
        final result = await ToolRegistry.executeTool('run_thread', {
          'name': 'ghost',
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], isNotNull);
      });

      test('returns queued status for existing thread', () async {
        await repo.layers.saveLayer(
          const LayerDefinition(name: 'L1', inputTypes: [], outputTypes: []),
        );
        await repo.layers.saveLayer(
          const LayerDefinition(name: 'L2', inputTypes: [], outputTypes: []),
        );
        await repo.threads.saveThread(
          const ThreadDefinition(
            name: 'T1',
            path: '/a',
            layerNames: ['L1', 'L2'],
          ),
        );

        final result = await ToolRegistry.executeTool('run_thread', {
          'name': 'T1',
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['status'], 'queued');
        expect(decoded['thread'], 'T1');
        expect(decoded['layerNames'], ['L1', 'L2']);
      });
    });

    group('get_queue_status', () {
      test('returns system summary', () async {
        await repo.layers.saveLayer(
          const LayerDefinition(
            name: 'L1',
            inputTypes: ['a'],
            outputTypes: ['b'],
          ),
        );
        await repo.workers.saveWorker(
          const WorkerDefinition(
            name: 'W1',
            layerName: 'L1',
            systemPrompt: 'p',
          ),
        );

        final result = await ToolRegistry.executeTool(
          'get_queue_status',
          {},
          repo,
        );
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['queueSize'], isA<int>());
        expect(decoded['layers'], 1);
        expect(decoded['workers'], 1);
        expect(decoded['threads'], isA<int>());
      });
    });

    group('assign_worker / unassign_worker', () {
      test('assign_worker returns error when layer not found', () async {
        await repo.layers.saveLayer(
          const LayerDefinition(name: '', inputTypes: [], outputTypes: []),
        );
        await repo.workers.saveWorker(
          const WorkerDefinition(name: 'W1', layerName: '', systemPrompt: 'p'),
        );

        final result = await ToolRegistry.executeTool('assign_worker', {
          'workerName': 'W1',
          'layerName': 'nope',
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], isNotNull);
      });

      test('assign_worker moves worker to layer', () async {
        await repo.layers.saveLayer(
          const LayerDefinition(
            name: 'L1',
            inputTypes: ['a'],
            outputTypes: ['b'],
          ),
        );
        await repo.layers.saveLayer(
          const LayerDefinition(name: '', inputTypes: [], outputTypes: []),
        );
        await repo.workers.saveWorker(
          const WorkerDefinition(name: 'W1', layerName: '', systemPrompt: 'p'),
        );

        final result = await ToolRegistry.executeTool('assign_worker', {
          'workerName': 'W1',
          'layerName': 'L1',
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['success'], true);

        final worker = await repo.workers.getWorker('W1');
        expect(worker!.layerName, 'L1');
      });

      test('unassign_worker removes worker from layer', () async {
        await repo.layers.saveLayer(
          const LayerDefinition(name: 'L1', inputTypes: [], outputTypes: []),
        );
        await repo.layers.saveLayer(
          const LayerDefinition(name: '', inputTypes: [], outputTypes: []),
        );
        await repo.workers.saveWorker(
          const WorkerDefinition(
            name: 'W1',
            layerName: 'L1',
            systemPrompt: 'p',
          ),
        );

        final result = await ToolRegistry.executeTool('unassign_worker', {
          'workerName': 'W1',
          'layerName': 'L1',
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['success'], true);

        final worker = await repo.workers.getWorker('W1');
        expect(worker!.layerName, '');
      });

      test('unassign_worker returns error when worker not on layer', () async {
        await repo.layers.saveLayer(
          const LayerDefinition(name: 'L2', inputTypes: [], outputTypes: []),
        );
        await repo.workers.saveWorker(
          const WorkerDefinition(
            name: 'W1',
            layerName: 'L2',
            systemPrompt: 'p',
          ),
        );

        final result = await ToolRegistry.executeTool('unassign_worker', {
          'workerName': 'W1',
          'layerName': 'L1',
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], isNotNull);
      });
    });

    group('update_thread', () {
      test('returns error when thread not found', () async {
        final result = await ToolRegistry.executeTool('update_thread', {
          'name': 'ghost',
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], isNotNull);
      });

      test('updates existing thread fields', () async {
        await repo.layers.saveLayer(
          const LayerDefinition(name: 'L1', inputTypes: [], outputTypes: []),
        );
        await repo.threads.saveThread(
          const ThreadDefinition(name: 'T1', path: '/old', layerNames: ['L1']),
        );

        await ToolRegistry.executeTool('update_thread', {
          'name': 'T1',
          'path': '/new',
          'contextPrompt': 'Legal review',
          'enabled': false,
        }, repo);

        final thread = await repo.threads.getThread('T1');
        expect(thread!.path, '/new');
        expect(thread.contextPrompt, 'Legal review');
        expect(thread.enabled, false);
      });
    });

    group('delete_thread', () {
      test('deletes a thread by name', () async {
        await repo.threads.saveThread(
          const ThreadDefinition(name: 'T1', path: '/a', layerNames: []),
        );

        final result = await ToolRegistry.executeTool('delete_thread', {
          'name': 'T1',
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['success'], true);

        final thread = await repo.threads.getThread('T1');
        expect(thread, isNull);
      });
    });

    group('get_status', () {
      test('returns thread status when threadName provided', () async {
        await repo.layers.saveLayer(
          const LayerDefinition(name: 'L1', inputTypes: [], outputTypes: []),
        );
        await repo.threads.saveThread(
          const ThreadDefinition(
            name: 'T1',
            path: '/a',
            layerNames: ['L1'],
            status: ThreadStatus.completed,
          ),
        );

        final result = await ToolRegistry.executeTool('get_status', {
          'threadName': 'T1',
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['thread'], 'T1');
        expect(decoded['status'], 'completed');
        expect(decoded['layerNames'], ['L1']);
      });

      test('returns error when threadName not found', () async {
        final result = await ToolRegistry.executeTool('get_status', {
          'threadName': 'ghost',
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], isNotNull);
      });

      test('returns system summary when no threadName', () async {
        await repo.layers.saveLayer(
          const LayerDefinition(
            name: 'L1',
            inputTypes: ['a'],
            outputTypes: ['b'],
          ),
        );
        await repo.workers.saveWorker(
          const WorkerDefinition(
            name: 'W1',
            layerName: 'L1',
            systemPrompt: 'p',
          ),
        );
        await repo.threads.saveThread(
          const ThreadDefinition(name: 'T1', path: '/a', layerNames: []),
        );

        final result = await ToolRegistry.executeTool('get_status', {}, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['layers'], 1);
        expect(decoded['workers'], 1);
        expect(decoded['threads'], 1);
      });
    });

    group('arrange_layers', () {
      test('returns success with reset message', () async {
        final result = await ToolRegistry.executeTool(
          'arrange_layers',
          {},
          repo,
        );
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['success'], true);
        expect(decoded['message'], isNotNull);
      });
    });

    group('get_worker_details', () {
      test('returns error when worker not found', () async {
        final result = await ToolRegistry.executeTool('get_worker_details', {
          'name': 'ghost',
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], isNotNull);
      });

      test('returns worker details with recent logs', () async {
        await repo.layers.saveLayer(
          const LayerDefinition(name: 'L1', inputTypes: [], outputTypes: []),
        );
        await repo.workers.saveWorker(
          const WorkerDefinition(
            name: 'W1',
            layerName: 'L1',
            systemPrompt: 'You parse text',
            model: 'gpt-4',
          ),
        );

        final result = await ToolRegistry.executeTool('get_worker_details', {
          'name': 'W1',
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['name'], 'W1');
        expect(decoded['layerName'], 'L1');
        expect(decoded['systemPrompt'], 'You parse text');
        expect(decoded['model'], 'gpt-4');
        expect(decoded['recentLogs'], isA<List<dynamic>>());
      });
    });

    group('list_logs', () {
      test('returns empty logs list', () async {
        final result = await ToolRegistry.executeTool('list_logs', {}, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['logs'], isEmpty);
      });
    });

    group('list_tasks', () {
      test('returns empty tasks list', () async {
        final result = await ToolRegistry.executeTool('list_tasks', {}, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['tasks'], isEmpty);
        expect(decoded['count'], 0);
      });
    });

    group('present_choices / confirm_action', () {
      test('present_choices echoes args as json', () async {
        final args = {
          'title': 'Pick a model',
          'options': ['gpt-4', 'claude-3'],
        };
        final result = await ToolRegistry.executeTool(
          'present_choices',
          args,
          repo,
        );
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded, args);
      });

      test('confirm_action echoes args as json', () async {
        final args = {
          'title': 'Delete?',
          'description': 'This cannot be undone',
          'action': 'delete_layer',
        };
        final result = await ToolRegistry.executeTool(
          'confirm_action',
          args,
          repo,
        );
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded, args);
      });
    });

    group('submit_task', () {
      test('creates a task with default medium priority', () async {
        final result = await ToolRegistry.executeTool('submit_task', {
          'taskType': 'custom_analysis',
          'payload': {'input': 'test data'},
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['success'], true);
        expect(decoded['taskId'], isA<String>());
        expect(decoded['status'], 'queued');

        final tasks = await repo.tasks.listTasks();
        expect(tasks, hasLength(1));
        expect(tasks.first.taskType, 'custom_analysis');
        expect(tasks.first.priority, TaskPriority.medium);
      });

      test('creates a task with explicit priority', () async {
        final result = await ToolRegistry.executeTool('submit_task', {
          'taskType': 'urgent_work',
          'payload': {'key': 'value'},
          'priority': 'high',
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['success'], true);

        final tasks = await repo.tasks.listTasks();
        expect(tasks.first.priority, TaskPriority.high);
      });

      test('falls back to medium priority for invalid priority', () async {
        final result = await ToolRegistry.executeTool('submit_task', {
          'taskType': 'work',
          'payload': <String, dynamic>{},
          'priority': 'invalid',
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['success'], true);

        final tasks = await repo.tasks.listTasks();
        expect(tasks.first.priority, TaskPriority.medium);
      });
    });
  });
}
