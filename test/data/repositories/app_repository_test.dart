import 'package:drift/drift.dart' hide isNotNull, isNull;
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

  group('listLayers', () {
    test('decodes JSON string fields into List<String>', () async {
      await db.saveLayer(
        LayersCompanion.insert(
          name: 'parse',
          inputTypes: '["raw_text"]',
          outputTypes: '["parsed_doc"]',
          sortOrder: const Value(1),
          enabled: const Value(true),
        ),
      );

      final layers = await repo.layers.listLayers();

      expect(layers, hasLength(1));
      final layer = layers.first;
      expect(layer.name, 'parse');
      expect(layer.inputTypes, ['raw_text']);
      expect(layer.outputTypes, ['parsed_doc']);
      expect(layer.order, 1);
      expect(layer.enabled, true);
    });

    test('round-trips layerPrompt', () async {
      await repo.layers.saveLayer(
        const LayerDefinition(
          name: 'with_prompt',
          inputTypes: ['raw'],
          outputTypes: ['parsed'],
          layerPrompt: 'Extract key clauses from contracts',
        ),
      );

      final layers = await repo.layers.listLayers();
      expect(layers, hasLength(1));
      expect(layers.first.layerPrompt, 'Extract key clauses from contracts');
    });

    test('layerPrompt defaults to null', () async {
      await repo.layers.saveLayer(
        const LayerDefinition(
          name: 'no_prompt',
          inputTypes: ['raw'],
          outputTypes: ['parsed'],
        ),
      );

      final layers = await repo.layers.listLayers();
      expect(layers.first.layerPrompt, isNull);
    });
  });

  group('saveLayer + deleteLayer', () {
    test('round-trips a LayerDefinition and deletes it', () async {
      await db.saveLayer(
        LayersCompanion.insert(
          name: 'eval',
          inputTypes: '["parsed_doc"]',
          outputTypes: '["eval_result"]',
          sortOrder: const Value(2),
        ),
      );

      var layers = await repo.layers.listLayers();
      expect(layers, hasLength(1));
      expect(layers.first.name, 'eval');

      await repo.layers.deleteLayer('eval');
      layers = await repo.layers.listLayers();
      expect(layers, isEmpty);
    });
  });

  group('getSettings', () {
    test('returns default settings when no settings stored', () async {
      final settings = await repo.settings.getSettings();
      expect(settings, equals(const ProviderSettings()));
    });

    test('returns parsed settings from valid JSON', () async {
      await db.saveSettings(
        '{"activeProvider":"Anthropic","configs":{"openAI":{"type":"openai","apiKey":"k1","model":"gpt-4o"},'
        '"anthropic":{"type":"anthropic","apiKey":"","model":"claude-sonnet-4-20250514"},'
        '"ollama":{"type":"ollama","baseUrl":"","model":"llama3"},'
        '"custom":{"type":"custom","baseUrl":"","apiKey":"","model":"","apiFormat":"openai"}},'
        '"default_temperature":0.7,"default_max_tokens":4096}',
      );

      final settings = await repo.settings.getSettings();
      expect(settings.activeProvider, ProviderType.anthropic);
      final openai = settings.configs[ProviderType.openAI] as OpenAIConfig;
      expect(openai.apiKey, 'k1');
    });

    test('returns default settings on malformed JSON', () async {
      await db.saveSettings('not-valid-json{{{');

      final settings = await repo.settings.getSettings();
      expect(settings, equals(const ProviderSettings()));
    });

    test(
      'returns default settings when stored value is not a JSON map',
      () async {
        await db.saveSettings('"just a string"');

        final settings = await repo.settings.getSettings();
        expect(settings, equals(const ProviderSettings()));
      },
    );
  });

  group('thread CRUD', () {
    test('saveThread and listThreads round-trip', () async {
      const thread = ThreadDefinition(
        name: 'review',
        path: '/home/user/project',
        layerNames: ['parse', 'analyze'],
      );
      await repo.threads.saveThread(thread);

      final threads = await repo.threads.listThreads();
      expect(threads, hasLength(1));
      expect(threads.first.name, 'review');
      expect(threads.first.path, '/home/user/project');
      expect(threads.first.layerNames, ['parse', 'analyze']);
      expect(threads.first.enabled, true);
      expect(threads.first.status, ThreadStatus.idle);
    });

    test('getThread returns null when not found', () async {
      final thread = await repo.threads.getThread('nonexistent');
      expect(thread, isNull);
    });

    test('getThread returns saved thread', () async {
      const thread = ThreadDefinition(
        name: 'build',
        path: '/src',
        layerNames: ['compile'],
        status: ThreadStatus.running,
      );
      await repo.threads.saveThread(thread);

      final found = await repo.threads.getThread('build');
      expect(found, isNotNull);
      expect(found!.name, 'build');
      expect(found.status, ThreadStatus.running);
    });

    test('deleteThread removes thread', () async {
      await repo.threads.saveThread(
        const ThreadDefinition(name: 'tmp', path: '/tmp', layerNames: []),
      );
      expect(await repo.threads.listThreads(), hasLength(1));

      await repo.threads.deleteThread('tmp');
      expect(await repo.threads.listThreads(), isEmpty);
    });

    test('saveThread upserts existing thread', () async {
      await repo.threads.saveThread(
        const ThreadDefinition(name: 't1', path: '/old', layerNames: ['A']),
      );
      await repo.threads.saveThread(
        const ThreadDefinition(
          name: 't1',
          path: '/new',
          layerNames: ['A', 'B'],
          enabled: false,
        ),
      );

      final threads = await repo.threads.listThreads();
      expect(threads, hasLength(1));
      expect(threads.first.path, '/new');
      expect(threads.first.layerNames, ['A', 'B']);
      expect(threads.first.enabled, false);
    });

    test('round-trips contextPrompt', () async {
      await repo.threads.saveThread(
        const ThreadDefinition(
          name: 'ctx_test',
          path: '/project',
          layerNames: ['L1'],
          contextPrompt: 'Legal document analysis pipeline',
        ),
      );

      final threads = await repo.threads.listThreads();
      expect(threads, hasLength(1));
      expect(threads.first.contextPrompt, 'Legal document analysis pipeline');
    });

    test('contextPrompt defaults to null', () async {
      await repo.threads.saveThread(
        const ThreadDefinition(
          name: 'no_ctx',
          path: '/project',
          layerNames: ['L1'],
        ),
      );

      final threads = await repo.threads.listThreads();
      expect(threads.first.contextPrompt, isNull);
    });
  });

  group('task CRUD', () {
    test('createTask stores and retrieves a task', () async {
      final id = await repo.tasks.createTask('summarize', {
        'text': 'hello',
      }, TaskPriority.high);

      final task = await repo.tasks.getTask(id);
      expect(task, isNotNull);
      expect(task!.taskType, 'summarize');
      expect(task.payload, {'text': 'hello'});
      expect(task.priority, TaskPriority.high);
      expect(task.status, TaskStatus.pending);
    });

    test('listTasks returns saved tasks', () async {
      await repo.tasks.createTask('a', null, TaskPriority.low);
      await repo.tasks.createTask('b', [1, 2], TaskPriority.medium);

      final tasks = await repo.tasks.listTasks();
      expect(tasks, hasLength(2));
    });
  });

  group('listLayers mixed-type JSON', () {
    test('filters non-string elements from inputTypes', () async {
      await db.saveLayer(
        LayersCompanion.insert(
          name: 'mixed-input',
          inputTypes: '["valid", 123, true, null, "also_valid"]',
          outputTypes: '[]',
          sortOrder: const Value(1),
          enabled: const Value(true),
        ),
      );

      final layers = await repo.layers.listLayers();
      expect(layers, hasLength(1));
      expect(layers.first.inputTypes, ['valid', 'also_valid']);
    });

    test('filters non-string elements from thread layerNames', () async {
      await db
          .into(db.threads)
          .insertOnConflictUpdate(
            ThreadsCompanion.insert(
              name: 'mixed-thread',
              path: '/mixed',
              layerNames: '["a", 1, null, "b"]',
            ),
          );

      final threads = await repo.threads.listThreads();
      expect(threads, hasLength(1));
      expect(threads.first.layerNames, ['a', 'b']);
    });
  });

  group('listLayers corrupted JSON', () {
    test('returns empty inputTypes for malformed JSON', () async {
      await db.saveLayer(
        LayersCompanion.insert(
          name: 'corrupt-input',
          inputTypes: 'not-valid-json{{{',
          outputTypes: '["ok"]',
          sortOrder: const Value(1),
          enabled: const Value(true),
        ),
      );

      final layers = await repo.layers.listLayers();
      expect(layers, hasLength(1));
      expect(layers.first.name, 'corrupt-input');
      expect(layers.first.inputTypes, isEmpty);
      expect(layers.first.outputTypes, ['ok']);
    });

    test('returns empty outputTypes for non-list JSON', () async {
      await db.saveLayer(
        LayersCompanion.insert(
          name: 'corrupt-output',
          inputTypes: '[]',
          outputTypes: '"a_string"',
          sortOrder: const Value(1),
          enabled: const Value(true),
        ),
      );

      final layers = await repo.layers.listLayers();
      expect(layers, hasLength(1));
      expect(layers.first.outputTypes, isEmpty);
    });
  });

  group('listThreads corrupted JSON', () {
    test('returns empty layerNames for malformed JSON', () async {
      await db
          .into(db.threads)
          .insertOnConflictUpdate(
            ThreadsCompanion.insert(
              name: 'ok',
              path: '/ok',
              layerNames: 'broken-json}}}',
            ),
          );

      final threads = await repo.threads.listThreads();
      expect(threads, hasLength(1));
      expect(threads.first.name, 'ok');
      expect(threads.first.layerNames, isEmpty);
    });

    test('returns empty layerNames for non-list JSON', () async {
      await db
          .into(db.threads)
          .insertOnConflictUpdate(
            ThreadsCompanion.insert(
              name: 'nonlist',
              path: '/p',
              layerNames: '"not_a_list"',
            ),
          );

      final threads = await repo.threads.listThreads();
      expect(threads, hasLength(1));
      expect(threads.first.layerNames, isEmpty);
    });
  });

  group('graph state error handling', () {
    test('loadNodePositions returns empty on type mismatch', () async {
      await db.saveJsonValue('graph_node_positions', '{"node1": "not_a_list"}');

      final positions = await repo.graph.loadNodePositions();
      expect(positions, isEmpty);
    });

    test('loadRemovedConnections returns empty on type mismatch', () async {
      await db.saveJsonValue('graph_removed_connections', '[123, 456]');

      final connections = await repo.graph.loadRemovedConnections();
      expect(connections, isEmpty);
    });

    test('loadViewport returns default on type mismatch', () async {
      await db.saveJsonValue('graph_viewport', '{"x": "not_a_number"}');

      final viewport = await repo.graph.loadViewport();
      expect(viewport, (0.0, 0.0, 1.0));
    });
  });
}
