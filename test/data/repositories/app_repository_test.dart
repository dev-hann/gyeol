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
      await db.saveThread(
        ThreadsCompanion.insert(name: 'default', path: '/tmp'),
      );
      final threads = await db.listThreads();
      final threadId = threads.first.id;
      await db.saveLayer(
        LayersCompanion.insert(
          threadId: threadId,
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
      await repo.threads.saveThread(
        const ThreadDefinition(id: 0, name: 't1', path: '/tmp'),
      );
      final thread = await repo.threads.getThread('t1');
      await repo.layers.saveLayer(
        LayerDefinition(
          id: 0,
          threadId: thread!.id,
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
      await repo.threads.saveThread(
        const ThreadDefinition(id: 0, name: 't2', path: '/tmp'),
      );
      final thread = await repo.threads.getThread('t2');
      await repo.layers.saveLayer(
        LayerDefinition(
          id: 0,
          threadId: thread!.id,
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
      await db.saveThread(
        ThreadsCompanion.insert(name: 'default', path: '/tmp'),
      );
      final threads = await db.listThreads();
      final threadId = threads.first.id;
      await db.saveLayer(
        LayersCompanion.insert(
          threadId: threadId,
          name: 'eval',
          inputTypes: '["parsed_doc"]',
          outputTypes: '["eval_result"]',
          sortOrder: const Value(2),
        ),
      );

      var layers = await repo.layers.listLayers();
      expect(layers, hasLength(1));
      expect(layers.first.name, 'eval');

      await repo.layers.deleteLayer(layers.first.id);
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
        '{"activeProvider":"Anthropic","configs":'
        '{"openAI":{"type":"openai","apiKey":"k1","model":"gpt-4o"},'
        '"anthropic":{"type":"anthropic","apiKey":"","'
        'model":"claude-sonnet-4-20250514"},'
        '"ollama":{"type":"ollama","baseUrl":"","model":"llama3"},'
        '"custom":{"type":"custom","baseUrl":"","apiKey":"",'
        '"model":"","apiFormat":"openai"}},'
        '"default_temperature":0.7,"default_max_tokens":4096}',
      );

      final settings = await repo.settings.getSettings();
      expect(settings.activeProvider, ProviderType.anthropic);
      final openai = settings.configs[ProviderType.openAI]! as OpenAIConfig;
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
      final thread = ThreadDefinition(
        id: 0,
        name: 'review',
        path: '/home/user/project',
      );
      await repo.threads.saveThread(thread);
      final saved = await repo.threads.getThread('review');
      await repo.layers.saveLayer(
        LayerDefinition(
          id: 0,
          threadId: saved!.id,
          name: 'parse',
          inputTypes: ['text'],
          outputTypes: [],
        ),
      );
      await repo.layers.saveLayer(
        LayerDefinition(
          id: 0,
          threadId: saved.id,
          name: 'analyze',
          inputTypes: ['text'],
          outputTypes: [],
        ),
      );

      final threads = await repo.threads.listThreads();
      expect(threads, hasLength(1));
      expect(threads.first.name, 'review');
      expect(threads.first.path, '/home/user/project');
      final threadLayers = await repo.layers.listLayersByThread(saved.id);
      expect(
        threadLayers.map((l) => l.name),
        containsAll(['parse', 'analyze']),
      );
      expect(threads.first.enabled, true);
      expect(threads.first.status, ThreadStatus.idle);
    });

    test('getThread returns null when not found', () async {
      final thread = await repo.threads.getThread('nonexistent');
      expect(thread, isNull);
    });

    test('getThread returns saved thread', () async {
      final thread = ThreadDefinition(
        id: 0,
        name: 'build',
        path: '/src',
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
        const ThreadDefinition(id: 1, name: 'tmp', path: '/tmp'),
      );
      expect(await repo.threads.listThreads(), hasLength(1));

      final tmpThread = await repo.threads.getThread('tmp');
      await repo.threads.deleteThread(tmpThread!.id);
      expect(await repo.threads.listThreads(), isEmpty);
    });

    test('saveThread upserts existing thread', () async {
      await repo.threads.saveThread(
        const ThreadDefinition(id: 0, name: 't1', path: '/old'),
      );
      final saved = await repo.threads.getThread('t1');
      await repo.layers.saveLayer(
        LayerDefinition(
          id: 0,
          threadId: saved!.id,
          name: 'A',
          inputTypes: ['text'],
          outputTypes: [],
        ),
      );
      await repo.layers.saveLayer(
        LayerDefinition(
          id: 0,
          threadId: saved.id,
          name: 'B',
          inputTypes: ['text'],
          outputTypes: [],
        ),
      );
      await repo.threads.saveThread(
        const ThreadDefinition(id: 3, name: 't1', path: '/new', enabled: false),
      );

      final threads = await repo.threads.listThreads();
      expect(threads, hasLength(1));
      expect(threads.first.path, '/new');
      final threadLayers = await repo.layers.listLayersByThread(saved.id);
      expect(threadLayers.map((l) => l.name), containsAll(['A', 'B']));
      expect(threads.first.enabled, false);
    });

    test('round-trips contextPrompt', () async {
      await repo.threads.saveThread(
        const ThreadDefinition(
          id: 4,
          name: 'ctx_test',
          path: '/project',
          contextPrompt: 'Legal document analysis pipeline',
        ),
      );

      final threads = await repo.threads.listThreads();
      expect(threads, hasLength(1));
      expect(threads.first.contextPrompt, 'Legal document analysis pipeline');
    });

    test('contextPrompt defaults to null', () async {
      await repo.threads.saveThread(
        const ThreadDefinition(id: 0, name: 'no_ctx', path: '/project'),
      );

      final threads = await repo.threads.listThreads();
      expect(threads.first.contextPrompt, isNull);
    });
  });

  group('task CRUD', () {
    test('createTask stores and retrieves a task', () async {
      await repo.tasks.createTask('summarize', {
        'text': 'hello',
      }, TaskPriority.high);

      final taskList = await repo.tasks.listTasks();
      final task = taskList.first;
      expect(task, isNotNull);
      expect(task.taskType, 'summarize');
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
      await db.saveThread(
        ThreadsCompanion.insert(name: 'default', path: '/tmp'),
      );
      final threads = await db.listThreads();
      final threadId = threads.first.id;
      await db.saveLayer(
        LayersCompanion.insert(
          threadId: threadId,
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

    test('thread layers are persisted via threadId FK', () async {
      await repo.threads.saveThread(
        const ThreadDefinition(id: 0, name: 'fk-test', path: '/fk'),
      );
      final thread = await repo.threads.getThread('fk-test');
      await repo.layers.saveLayer(
        LayerDefinition(
          id: 0,
          threadId: thread!.id,
          name: 'a',
          inputTypes: ['text'],
          outputTypes: [],
        ),
      );
      await repo.layers.saveLayer(
        LayerDefinition(
          id: 0,
          threadId: thread.id,
          name: 'b',
          inputTypes: ['text'],
          outputTypes: [],
        ),
      );

      final threadLayers = await repo.layers.listLayersByThread(thread.id);
      expect(threadLayers, hasLength(2));
      expect(threadLayers.map((l) => l.name), containsAll(['a', 'b']));
    });
  });

  group('listLayers corrupted JSON', () {
    test('returns empty inputTypes for malformed JSON', () async {
      await db.saveThread(
        ThreadsCompanion.insert(name: 'default', path: '/tmp'),
      );
      final threads = await db.listThreads();
      final threadId = threads.first.id;
      await db.saveLayer(
        LayersCompanion.insert(
          threadId: threadId,
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
      await db.saveThread(
        ThreadsCompanion.insert(name: 'default2', path: '/tmp'),
      );
      final threads = await db.listThreads();
      final threadId = threads.first.id;
      await db.saveLayer(
        LayersCompanion.insert(
          threadId: threadId,
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

  group('thread layers via threadId FK', () {
    test('empty layers for thread with no layers', () async {
      await repo.threads.saveThread(
        const ThreadDefinition(id: 7, name: 'empty', path: '/empty'),
      );

      final threads = await repo.threads.listThreads();
      expect(threads, hasLength(1));
      expect(threads.first.name, 'empty');
      final threadLayers = await repo.layers.listLayersByThread(
        threads.first.id,
      );
      expect(threadLayers, isEmpty);
    });

    test('layers populated via threadId', () async {
      await repo.threads.saveThread(
        const ThreadDefinition(id: 0, name: 'layered', path: '/p'),
      );
      final thread = await repo.threads.getThread('layered');
      await repo.layers.saveLayer(
        LayerDefinition(
          id: 0,
          threadId: thread!.id,
          name: 'L1',
          inputTypes: ['text'],
          outputTypes: [],
        ),
      );
      await repo.layers.saveLayer(
        LayerDefinition(
          id: 0,
          threadId: thread.id,
          name: 'L2',
          inputTypes: ['text'],
          outputTypes: [],
        ),
      );

      final threadLayers = await repo.layers.listLayersByThread(thread.id);
      expect(threadLayers, hasLength(2));
      expect(threadLayers.map((l) => l.name), containsAll(['L1', 'L2']));
    });
  });

  group('graph state error handling', () {
    test('loadNodePositions returns empty on type mismatch', () async {
      await db.saveUiState('graph_node_positions', '{"node1": "not_a_list"}');

      final positions = await repo.graph.loadNodePositions();
      expect(positions, isEmpty);
    });

    test('loadViewport returns default on type mismatch', () async {
      await db.saveUiState('graph_viewport', '{"x": "not_a_number"}');

      final viewport = await repo.graph.loadViewport();
      expect(viewport, (0.0, 0.0, 1.0));
    });
  });
}
