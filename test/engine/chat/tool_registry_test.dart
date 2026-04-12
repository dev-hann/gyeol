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

      test('returns descriptive error when name is missing', () async {
        final result = await ToolRegistry.executeTool('create_layer', {
          'inputTypes': ['text'],
          'outputTypes': ['tokens'],
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], contains('name'));
      });

      test('returns descriptive error when inputTypes is missing', () async {
        final result = await ToolRegistry.executeTool('create_layer', {
          'name': 'L',
          'outputTypes': ['tokens'],
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], contains('inputTypes'));
      });

      test('returns descriptive error when outputTypes is missing', () async {
        final result = await ToolRegistry.executeTool('create_layer', {
          'name': 'L',
          'inputTypes': ['text'],
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], contains('outputTypes'));
      });

      test('returns descriptive error when name is not a String', () async {
        final result = await ToolRegistry.executeTool('create_layer', {
          'name': 123,
          'inputTypes': ['text'],
          'outputTypes': ['tokens'],
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], contains('name'));
      });

      test('returns descriptive error when inputTypes is not a List', () async {
        final result = await ToolRegistry.executeTool('create_layer', {
          'name': 'L',
          'inputTypes': 'not-a-list',
          'outputTypes': ['tokens'],
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], contains('inputTypes'));
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
            id: 0,
            name: 'L1',
            inputTypes: ['text'],
            outputTypes: ['analysis'],
          ),
        );
        await repo.workers.saveWorker(
          const WorkerDefinition(
            id: 0,
            name: 'W1',
            layerId: 1,
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
      test('returns descriptive error when name is not a String', () async {
        final result = await ToolRegistry.executeTool('update_layer', {
          'name': 123,
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], contains('name'));
      });

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
            id: 0,
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
            id: 0,
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

      test('returns descriptive error when name is not a String', () async {
        final result = await ToolRegistry.executeTool('delete_layer', {
          'name': 123,
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], contains('name'));
      });

      test('returns descriptive error when name is missing', () async {
        final result = await ToolRegistry.executeTool('delete_layer', {}, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], contains('name'));
      });
    });

    group('create_worker', () {
      test('creates a worker and returns success', () async {
        await repo.layers.saveLayer(
          const LayerDefinition(
            id: 0,
            name: 'L1',
            inputTypes: [],
            outputTypes: [],
          ),
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
        final layers = await repo.layers.listLayers();
        final l1 = layers.firstWhere((l) => l.name == 'L1');
        expect(worker!.layerId, l1.id);
        expect(worker.systemPrompt, 'You are a parser');
        expect(worker.model, 'gpt-4');
        expect(worker.temperature, 0.5);
        expect(worker.maxTokens, 2048);
      });

      test('returns descriptive error when name is not a String', () async {
        final result = await ToolRegistry.executeTool('create_worker', {
          'name': 123,
          'layerName': 'L1',
          'systemPrompt': 'prompt',
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], contains('name'));
      });

      test('returns descriptive error when name is missing', () async {
        final result = await ToolRegistry.executeTool('create_worker', {
          'layerName': 'L1',
          'systemPrompt': 'prompt',
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], contains('name'));
      });

      test(
        'returns descriptive error when layerName is not a String',
        () async {
          final result = await ToolRegistry.executeTool('create_worker', {
            'name': 'W1',
            'layerName': 456,
            'systemPrompt': 'prompt',
          }, repo);
          final decoded = jsonDecode(result) as Map<String, dynamic>;
          expect(decoded['error'], contains('layerName'));
        },
      );

      test('returns descriptive error when layerName is missing', () async {
        final result = await ToolRegistry.executeTool('create_worker', {
          'name': 'W1',
          'systemPrompt': 'prompt',
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], contains('layerName'));
      });

      test(
        'returns descriptive error when systemPrompt is not a String',
        () async {
          final result = await ToolRegistry.executeTool('create_worker', {
            'name': 'W1',
            'layerName': 'L1',
            'systemPrompt': true,
          }, repo);
          final decoded = jsonDecode(result) as Map<String, dynamic>;
          expect(decoded['error'], contains('systemPrompt'));
        },
      );

      test('returns descriptive error when systemPrompt is missing', () async {
        final result = await ToolRegistry.executeTool('create_worker', {
          'name': 'W1',
          'layerName': 'L1',
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], contains('systemPrompt'));
      });
    });

    group('list_workers', () {
      test('returns workers filtered by layerName', () async {
        await repo.layers.saveLayer(
          const LayerDefinition(
            id: 0,
            name: 'L1',
            inputTypes: [],
            outputTypes: [],
          ),
        );
        await repo.layers.saveLayer(
          const LayerDefinition(
            id: 0,
            name: 'L2',
            inputTypes: [],
            outputTypes: [],
          ),
        );
        final savedLayers = await repo.layers.listLayers();
        final l1 = savedLayers.firstWhere((l) => l.name == 'L1');
        final l2 = savedLayers.firstWhere((l) => l.name == 'L2');
        await repo.workers.saveWorker(
          WorkerDefinition(
            id: 0,
            name: 'W1',
            layerId: l1.id,
            systemPrompt: 'p1',
          ),
        );
        await repo.workers.saveWorker(
          WorkerDefinition(
            id: 0,
            name: 'W2',
            layerId: l2.id,
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
      test('returns descriptive error when name is not a String', () async {
        final result = await ToolRegistry.executeTool('update_worker', {
          'name': 456,
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], contains('name'));
      });

      test('returns error when worker not found', () async {
        final result = await ToolRegistry.executeTool('update_worker', {
          'name': 'ghost',
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], isNotNull);
      });

      test('updates existing worker', () async {
        await repo.layers.saveLayer(
          const LayerDefinition(
            id: 0,
            name: 'L1',
            inputTypes: [],
            outputTypes: [],
          ),
        );
        await repo.workers.saveWorker(
          const WorkerDefinition(
            id: 0,
            name: 'W1',
            layerId: 1,
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
      test('returns descriptive error when name is not a String', () async {
        final result = await ToolRegistry.executeTool('delete_worker', {
          'name': 789,
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], contains('name'));
      });

      test('deletes a worker by name', () async {
        await repo.layers.saveLayer(
          const LayerDefinition(
            id: 0,
            name: 'L1',
            inputTypes: [],
            outputTypes: [],
          ),
        );
        await repo.workers.saveWorker(
          const WorkerDefinition(
            id: 0,
            name: 'W1',
            layerId: 1,
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
      test('returns descriptive error when name is not a String', () async {
        final result = await ToolRegistry.executeTool('create_thread', {
          'name': 100,
          'path': '/a',
          'layerNames': ['L1'],
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], contains('name'));
      });

      test('returns descriptive error when path is not a String', () async {
        final result = await ToolRegistry.executeTool('create_thread', {
          'name': 'T1',
          'path': 42,
          'layerNames': ['L1'],
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], contains('path'));
      });

      test('returns descriptive error when layerNames is not a List', () async {
        final result = await ToolRegistry.executeTool('create_thread', {
          'name': 'T1',
          'path': '/a',
          'layerNames': 'not-a-list',
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], contains('layerNames'));
      });

      test('creates a thread and returns success', () async {
        await repo.layers.saveLayer(
          const LayerDefinition(
            id: 0,
            name: 'L1',
            inputTypes: [],
            outputTypes: [],
          ),
        );
        await repo.layers.saveLayer(
          const LayerDefinition(
            id: 0,
            name: 'L2',
            inputTypes: [],
            outputTypes: [],
          ),
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
        final savedLayers = await repo.layers.listLayers();
        final l1Id = savedLayers.firstWhere((l) => l.name == 'L1').id;
        final l2Id = savedLayers.firstWhere((l) => l.name == 'L2').id;
        expect(thread.layerIds, [l1Id, l2Id]);
      });
    });

    group('list_threads', () {
      test('returns all threads', () async {
        await repo.layers.saveLayer(
          const LayerDefinition(
            id: 0,
            name: 'L1',
            inputTypes: [],
            outputTypes: [],
          ),
        );
        await repo.threads.saveThread(
          const ThreadDefinition(id: 0, name: 'T1', path: '/a', layerIds: [1]),
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
      test('returns descriptive error when name is not a String', () async {
        final result = await ToolRegistry.executeTool('run_thread', {
          'name': 999,
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], contains('name'));
      });

      test('returns error when thread not found', () async {
        final result = await ToolRegistry.executeTool('run_thread', {
          'name': 'ghost',
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], isNotNull);
      });

      test('returns queued status for existing thread', () async {
        await repo.layers.saveLayer(
          const LayerDefinition(
            id: 0,
            name: 'L1',
            inputTypes: [],
            outputTypes: [],
          ),
        );
        await repo.layers.saveLayer(
          const LayerDefinition(
            id: 0,
            name: 'L2',
            inputTypes: [],
            outputTypes: [],
          ),
        );
        await repo.threads.saveThread(
          const ThreadDefinition(
            id: 0,
            name: 'T1',
            path: '/a',
            layerIds: [1, 2],
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
            id: 0,
            name: 'L1',
            inputTypes: ['a'],
            outputTypes: ['b'],
          ),
        );
        await repo.workers.saveWorker(
          const WorkerDefinition(
            id: 0,
            name: 'W1',
            layerId: 1,
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
      test(
        'assign_worker returns error when workerName is not a String',
        () async {
          final result = await ToolRegistry.executeTool('assign_worker', {
            'workerName': 123,
            'layerName': 'L1',
          }, repo);
          final decoded = jsonDecode(result) as Map<String, dynamic>;
          expect(decoded['error'], contains('workerName'));
        },
      );

      test(
        'assign_worker returns error when layerName is not a String',
        () async {
          final result = await ToolRegistry.executeTool('assign_worker', {
            'workerName': 'W1',
            'layerName': 456,
          }, repo);
          final decoded = jsonDecode(result) as Map<String, dynamic>;
          expect(decoded['error'], contains('layerName'));
        },
      );

      test('assign_worker returns error when layer not found', () async {
        await repo.layers.saveLayer(
          const LayerDefinition(
            id: 0,
            name: '',
            inputTypes: [],
            outputTypes: [],
          ),
        );
        await repo.workers.saveWorker(
          const WorkerDefinition(
            id: 0,
            name: 'W1',
            layerId: 1,
            systemPrompt: 'p',
          ),
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
            id: 0,
            name: 'L1',
            inputTypes: ['a'],
            outputTypes: ['b'],
          ),
        );
        await repo.layers.saveLayer(
          const LayerDefinition(
            id: 0,
            name: 'L2',
            inputTypes: [],
            outputTypes: [],
          ),
        );
        final savedLayers = await repo.layers.listLayers();
        final l1 = savedLayers.firstWhere((l) => l.name == 'L1');
        final l2 = savedLayers.firstWhere((l) => l.name == 'L2');
        await repo.workers.saveWorker(
          WorkerDefinition(
            id: 0,
            name: 'W1',
            layerId: l2.id,
            systemPrompt: 'p',
          ),
        );

        final result = await ToolRegistry.executeTool('assign_worker', {
          'workerName': 'W1',
          'layerName': 'L1',
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['success'], true);

        final worker = await repo.workers.getWorker('W1');
        expect(worker!.layerId, l1.id);
      });

      test('unassign_worker returns error since layerId is required', () async {
        await repo.layers.saveLayer(
          const LayerDefinition(
            id: 0,
            name: 'L1',
            inputTypes: [],
            outputTypes: [],
          ),
        );
        final savedLayers = await repo.layers.listLayers();
        final l1 = savedLayers.firstWhere((l) => l.name == 'L1');
        await repo.workers.saveWorker(
          WorkerDefinition(
            id: 0,
            name: 'W1',
            layerId: l1.id,
            systemPrompt: 'p',
          ),
        );

        final result = await ToolRegistry.executeTool('unassign_worker', {
          'workerName': 'W1',
          'layerName': 'L1',
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], isNotNull);

        final worker = await repo.workers.getWorker('W1');
        expect(worker!.layerId, l1.id);
      });

      test('unassign_worker returns error when worker not on layer', () async {
        await repo.layers.saveLayer(
          const LayerDefinition(
            id: 0,
            name: 'L2',
            inputTypes: [],
            outputTypes: [],
          ),
        );
        final savedLayers = await repo.layers.listLayers();
        final l2 = savedLayers.firstWhere((l) => l.name == 'L2');
        await repo.workers.saveWorker(
          WorkerDefinition(
            id: 0,
            name: 'W1',
            layerId: l2.id,
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
      test('returns descriptive error when name is not a String', () async {
        final result = await ToolRegistry.executeTool('update_thread', {
          'name': 222,
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], contains('name'));
      });

      test('returns error when thread not found', () async {
        final result = await ToolRegistry.executeTool('update_thread', {
          'name': 'ghost',
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], isNotNull);
      });

      test('updates existing thread fields', () async {
        await repo.layers.saveLayer(
          const LayerDefinition(
            id: 0,
            name: 'L1',
            inputTypes: [],
            outputTypes: [],
          ),
        );
        await repo.threads.saveThread(
          const ThreadDefinition(
            id: 0,
            name: 'T1',
            path: '/old',
            layerIds: [1],
          ),
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
      test('returns descriptive error when name is not a String', () async {
        final result = await ToolRegistry.executeTool('delete_thread', {
          'name': 333,
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], contains('name'));
      });

      test('deletes a thread by name', () async {
        await repo.threads.saveThread(
          const ThreadDefinition(id: 0, name: 'T1', path: '/a', layerIds: []),
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
          const LayerDefinition(
            id: 0,
            name: 'L1',
            inputTypes: [],
            outputTypes: [],
          ),
        );
        await repo.threads.saveThread(
          const ThreadDefinition(
            id: 0,
            name: 'T1',
            path: '/a',
            layerIds: [1],
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
            id: 0,
            name: 'L1',
            inputTypes: ['a'],
            outputTypes: ['b'],
          ),
        );
        await repo.workers.saveWorker(
          const WorkerDefinition(
            id: 0,
            name: 'W1',
            layerId: 1,
            systemPrompt: 'p',
          ),
        );
        await repo.threads.saveThread(
          const ThreadDefinition(id: 0, name: 'T1', path: '/a', layerIds: []),
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
      test('returns descriptive error when name is not a String', () async {
        final result = await ToolRegistry.executeTool('get_worker_details', {
          'name': 555,
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], contains('name'));
      });

      test('returns error when worker not found', () async {
        final result = await ToolRegistry.executeTool('get_worker_details', {
          'name': 'ghost',
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], isNotNull);
      });

      test('returns worker details with recent logs', () async {
        await repo.layers.saveLayer(
          const LayerDefinition(
            id: 0,
            name: 'L1',
            inputTypes: [],
            outputTypes: [],
          ),
        );
        await repo.workers.saveWorker(
          const WorkerDefinition(
            id: 0,
            name: 'W1',
            layerId: 1,
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

    group('list_providers', () {
      test('returns all four providers with default settings', () async {
        final result = await ToolRegistry.executeTool(
          'list_providers',
          <String, dynamic>{},
          repo,
        );
        final decoded = jsonDecode(result) as List<dynamic>;
        expect(decoded, hasLength(4));

        final names = decoded
            .map((e) => (e as Map<String, dynamic>)['provider'] as String)
            .toSet();
        expect(names, containsAll(['openAI', 'anthropic', 'ollama', 'custom']));
      });

      test('marks all unconfigured when no API keys set', () async {
        final result = await ToolRegistry.executeTool(
          'list_providers',
          <String, dynamic>{},
          repo,
        );
        final decoded = jsonDecode(result) as List<dynamic>;
        for (final entry in decoded) {
          final provider = entry as Map<String, dynamic>;
          expect(provider['is_configured'], isFalse);
          expect(provider['available_models'], isEmpty);
        }
      });

      test('marks configured provider and active provider', () async {
        await repo.settings.saveSettings(
          const ProviderSettings(
            configs: {
              ProviderType.openAI: OpenAIConfig(apiKey: 'sk-test'),
              ProviderType.anthropic: AnthropicConfig(),
              ProviderType.ollama: OllamaConfig(),
              ProviderType.custom: CustomConfig(),
            },
          ),
        );

        final result = await ToolRegistry.executeTool(
          'list_providers',
          <String, dynamic>{},
          repo,
        );
        final decoded = jsonDecode(result) as List<dynamic>;
        final openai =
            decoded.firstWhere(
                  (e) => (e as Map<String, dynamic>)['provider'] == 'openAI',
                )
                as Map<String, dynamic>;
        expect(openai['is_configured'], isTrue);
        expect(openai['is_active'], isTrue);

        final anthropic =
            decoded.firstWhere(
                  (e) => (e as Map<String, dynamic>)['provider'] == 'anthropic',
                )
                as Map<String, dynamic>;
        expect(anthropic['is_configured'], isFalse);
        expect(anthropic['is_active'], isFalse);
      });

      test('reflects active provider change', () async {
        await repo.settings.saveSettings(
          const ProviderSettings(
            activeProvider: ProviderType.anthropic,
            configs: {
              ProviderType.openAI: OpenAIConfig(apiKey: 'sk-test'),
              ProviderType.anthropic: AnthropicConfig(apiKey: 'sk-ant-test'),
              ProviderType.ollama: OllamaConfig(),
              ProviderType.custom: CustomConfig(),
            },
          ),
        );

        final result = await ToolRegistry.executeTool(
          'list_providers',
          <String, dynamic>{},
          repo,
        );
        final decoded = jsonDecode(result) as List<dynamic>;
        final anthropic =
            decoded.firstWhere(
                  (e) => (e as Map<String, dynamic>)['provider'] == 'anthropic',
                )
                as Map<String, dynamic>;
        expect(anthropic['is_active'], isTrue);
        expect(anthropic['is_configured'], isTrue);
      });

      test('includes current_model from config', () async {
        await repo.settings.saveSettings(
          const ProviderSettings(
            configs: {
              ProviderType.openAI: OpenAIConfig(
                apiKey: 'sk-test',
                model: 'gpt-4-turbo',
              ),
              ProviderType.anthropic: AnthropicConfig(),
              ProviderType.ollama: OllamaConfig(),
              ProviderType.custom: CustomConfig(),
            },
          ),
        );

        final result = await ToolRegistry.executeTool(
          'list_providers',
          <String, dynamic>{},
          repo,
        );
        final decoded = jsonDecode(result) as List<dynamic>;
        final openai =
            decoded.firstWhere(
                  (e) => (e as Map<String, dynamic>)['provider'] == 'openAI',
                )
                as Map<String, dynamic>;
        expect(openai['current_model'], 'gpt-4-turbo');
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

      test('returns descriptive error when payload is not a Map', () async {
        final result = await ToolRegistry.executeTool('submit_task', {
          'taskType': 'work',
          'payload': 'not_a_map',
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], contains('payload'));
      });

      test('returns descriptive error when payload is missing', () async {
        final result = await ToolRegistry.executeTool('submit_task', {
          'taskType': 'work',
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], contains('payload'));
      });

      test('returns error when taskType is not a String', () async {
        final result = await ToolRegistry.executeTool('submit_task', {
          'taskType': 42,
          'payload': <String, dynamic>{},
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], isNotNull);
      });
    });

    group('switch_provider', () {
      test('returns descriptive error when provider is not a String', () async {
        final result = await ToolRegistry.executeTool('switch_provider', {
          'provider': 404,
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], contains('provider'));
      });

      test('returns error for unknown provider name', () async {
        final result = await ToolRegistry.executeTool('switch_provider', {
          'provider': 'unknown',
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], contains('Unknown provider'));
      });

      test('returns error for unconfigured provider', () async {
        await repo.settings.saveSettings(const ProviderSettings());
        final result = await ToolRegistry.executeTool('switch_provider', {
          'provider': 'openai',
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], contains('not configured'));
      });

      test('switches to configured provider', () async {
        await repo.settings.saveSettings(
          const ProviderSettings(
            configs: {
              ProviderType.openAI: OpenAIConfig(apiKey: 'sk-test'),
              ProviderType.anthropic: AnthropicConfig(),
              ProviderType.ollama: OllamaConfig(),
              ProviderType.custom: CustomConfig(),
            },
          ),
        );
        final result = await ToolRegistry.executeTool('switch_provider', {
          'provider': 'openai',
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['success'], true);
        expect(decoded['activeProvider'], 'openai');
      });
    });

    group('rename_conversation', () {
      test(
        'returns descriptive error when conversationId is not a String',
        () async {
          final result = await ToolRegistry.executeTool('rename_conversation', {
            'conversationId': 111,
            'title': 'Title',
          }, repo);
          final decoded = jsonDecode(result) as Map<String, dynamic>;
          expect(decoded['error'], contains('conversationId'));
        },
      );

      test('returns descriptive error when title is not a String', () async {
        final result = await ToolRegistry.executeTool('rename_conversation', {
          'conversationId': 'abc',
          'title': 222,
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], contains('title'));
      });

      test('renames existing conversation', () async {
        final conv = ChatConversation.create('Old Title');
        await repo.chat.saveConversation(conv);
        final result = await ToolRegistry.executeTool('rename_conversation', {
          'conversationId': conv.id,
          'title': 'New Title',
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['success'], true);
        final convs = await repo.chat.listConversations();
        expect(convs.first.title, 'New Title');
      });

      test('returns error for non-existent conversation', () async {
        final result = await ToolRegistry.executeTool('rename_conversation', {
          'conversationId': 'nonexistent',
          'title': 'New',
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], isNotNull);
      });
    });

    group('search_messages', () {
      test('returns descriptive error when query is not a String', () async {
        final result = await ToolRegistry.executeTool('search_messages', {
          'query': 333,
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], contains('query'));
      });

      test('finds matching messages across conversations', () async {
        final conv = ChatConversation.create('Test');
        await repo.chat.saveConversation(conv);
        await repo.chat.saveMessage(
          ChatMessage.create(
            conversationId: conv.id,
            role: 'user',
            content: 'Hello world',
          ),
        );
        await repo.chat.saveMessage(
          ChatMessage.create(
            conversationId: conv.id,
            role: 'assistant',
            content: 'Hi there',
          ),
        );
        final result = await ToolRegistry.executeTool('search_messages', {
          'query': 'hello',
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        final messages = (decoded['messages'] as List)
            .cast<Map<String, dynamic>>();
        expect(messages, hasLength(1));
        expect(messages.first['content'], contains('Hello'));
      });

      test('returns empty for no matches', () async {
        final conv = ChatConversation.create('Test');
        await repo.chat.saveConversation(conv);
        await repo.chat.saveMessage(
          ChatMessage.create(
            conversationId: conv.id,
            role: 'user',
            content: 'Hello world',
          ),
        );
        final result = await ToolRegistry.executeTool('search_messages', {
          'query': 'xyz_not_found',
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['messages'], isEmpty);
      });

      test('respects limit parameter', () async {
        final conv = ChatConversation.create('Test');
        await repo.chat.saveConversation(conv);
        for (var i = 0; i < 5; i++) {
          await repo.chat.saveMessage(
            ChatMessage.create(
              conversationId: conv.id,
              role: 'user',
              content: 'test query $i',
            ),
          );
        }
        final result = await ToolRegistry.executeTool('search_messages', {
          'query': 'test query',
          'limit': 2,
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        final messages = (decoded['messages'] as List)
            .cast<Map<String, dynamic>>();
        expect(messages, hasLength(2));
      });

      test('filters by conversationId', () async {
        final conv1 = ChatConversation.create('C1');
        final conv2 = ChatConversation.create('C2');
        await repo.chat.saveConversation(conv1);
        await repo.chat.saveConversation(conv2);
        await repo.chat.saveMessage(
          ChatMessage.create(
            conversationId: conv1.id,
            role: 'user',
            content: 'unique keyword alpha',
          ),
        );
        await repo.chat.saveMessage(
          ChatMessage.create(
            conversationId: conv2.id,
            role: 'user',
            content: 'unique keyword beta',
          ),
        );
        final result = await ToolRegistry.executeTool('search_messages', {
          'query': 'unique keyword',
          'conversationId': conv1.id,
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        final messages = (decoded['messages'] as List)
            .cast<Map<String, dynamic>>();
        expect(messages, hasLength(1));
        expect(messages.first['content'], contains('alpha'));
      });
    });

    group('clear_conversation', () {
      test(
        'returns descriptive error when conversationId is not a String',
        () async {
          final result = await ToolRegistry.executeTool('clear_conversation', {
            'conversationId': 444,
          }, repo);
          final decoded = jsonDecode(result) as Map<String, dynamic>;
          expect(decoded['error'], contains('conversationId'));
        },
      );

      test('clears all messages from conversation', () async {
        final conv = ChatConversation.create('Test');
        await repo.chat.saveConversation(conv);
        await repo.chat.saveMessage(
          ChatMessage.create(
            conversationId: conv.id,
            role: 'user',
            content: 'Hello',
          ),
        );
        await repo.chat.saveMessage(
          ChatMessage.create(
            conversationId: conv.id,
            role: 'assistant',
            content: 'Hi',
          ),
        );
        final result = await ToolRegistry.executeTool('clear_conversation', {
          'conversationId': conv.id,
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['success'], true);
        final messages = await repo.chat.listMessages(conv.id);
        expect(messages, isEmpty);
      });
    });

    group('export_conversation', () {
      test(
        'returns descriptive error when conversationId is not a String',
        () async {
          final result = await ToolRegistry.executeTool('export_conversation', {
            'conversationId': 555,
          }, repo);
          final decoded = jsonDecode(result) as Map<String, dynamic>;
          expect(decoded['error'], contains('conversationId'));
        },
      );

      test('exports conversation as markdown', () async {
        final conv = ChatConversation.create('My Chat');
        await repo.chat.saveConversation(conv);
        await repo.chat.saveMessage(
          ChatMessage.create(
            conversationId: conv.id,
            role: 'user',
            content: 'Hello',
          ),
        );
        await repo.chat.saveMessage(
          ChatMessage.create(
            conversationId: conv.id,
            role: 'assistant',
            content: 'World',
          ),
        );
        final result = await ToolRegistry.executeTool('export_conversation', {
          'conversationId': conv.id,
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['markdown'], contains('My Chat'));
        expect(decoded['markdown'], contains('User'));
        expect(decoded['markdown'], contains('Hello'));
        expect(decoded['markdown'], contains('Assistant'));
        expect(decoded['markdown'], contains('World'));
      });

      test('returns error for non-existent conversation', () async {
        final result = await ToolRegistry.executeTool('export_conversation', {
          'conversationId': 'nonexistent',
        }, repo);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], isNotNull);
      });
    });
  });
}
