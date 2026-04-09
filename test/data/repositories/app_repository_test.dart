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
          workerNames: '["parser_a","parser_b"]',
          sortOrder: const Value(1),
          enabled: const Value(true),
        ),
      );

      final layers = await repo.listLayers();

      expect(layers, hasLength(1));
      final layer = layers.first;
      expect(layer.name, 'parse');
      expect(layer.inputTypes, ['raw_text']);
      expect(layer.outputTypes, ['parsed_doc']);
      expect(layer.workerNames, ['parser_a', 'parser_b']);
      expect(layer.order, 1);
      expect(layer.enabled, true);
    });
  });

  group('saveLayer + deleteLayer', () {
    test('round-trips a LayerDefinition and deletes it', () async {
      await db.saveLayer(
        LayersCompanion.insert(
          name: 'eval',
          inputTypes: '["parsed_doc"]',
          outputTypes: '["eval_result"]',
          workerNames: '["evaluator"]',
          sortOrder: const Value(2),
        ),
      );

      var layers = await repo.listLayers();
      expect(layers, hasLength(1));
      expect(layers.first.name, 'eval');

      await repo.deleteLayer('eval');
      layers = await repo.listLayers();
      expect(layers, isEmpty);
    });
  });

  group('getSettings', () {
    test('returns default settings when no settings stored', () async {
      final settings = await repo.getSettings();
      expect(settings, equals(const ProviderSettings()));
    });

    test('returns parsed settings from valid JSON', () async {
      await db.saveSettings(
        '{"provider":"Anthropic","openai_api_key":"k1","openai_model":"gpt-4o",'
        '"anthropic_api_key":"","anthropic_model":"claude-sonnet-4-20250514",'
        '"ollama_base_url":"http://localhost:11434","ollama_model":"llama3",'
        '"default_temperature":0.7,"default_max_tokens":4096}',
      );

      final settings = await repo.getSettings();
      expect(settings.provider, ProviderType.anthropic);
      expect(settings.openaiApiKey, 'k1');
    });

    test('returns default settings on malformed JSON', () async {
      await db.saveSettings('not-valid-json{{{');

      final settings = await repo.getSettings();
      expect(settings, equals(const ProviderSettings()));
    });

    test(
      'returns default settings when stored value is not a JSON map',
      () async {
        await db.saveSettings('"just a string"');

        final settings = await repo.getSettings();
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
      await repo.saveThread(thread);

      final threads = await repo.listThreads();
      expect(threads, hasLength(1));
      expect(threads.first.name, 'review');
      expect(threads.first.path, '/home/user/project');
      expect(threads.first.layerNames, ['parse', 'analyze']);
      expect(threads.first.enabled, true);
      expect(threads.first.status, ThreadStatus.idle);
    });

    test('getThread returns null when not found', () async {
      final thread = await repo.getThread('nonexistent');
      expect(thread, isNull);
    });

    test('getThread returns saved thread', () async {
      const thread = ThreadDefinition(
        name: 'build',
        path: '/src',
        layerNames: ['compile'],
        status: ThreadStatus.running,
      );
      await repo.saveThread(thread);

      final found = await repo.getThread('build');
      expect(found, isNotNull);
      expect(found!.name, 'build');
      expect(found.status, ThreadStatus.running);
    });

    test('deleteThread removes thread', () async {
      await repo.saveThread(
        const ThreadDefinition(name: 'tmp', path: '/tmp', layerNames: []),
      );
      expect(await repo.listThreads(), hasLength(1));

      await repo.deleteThread('tmp');
      expect(await repo.listThreads(), isEmpty);
    });

    test('saveThread upserts existing thread', () async {
      await repo.saveThread(
        const ThreadDefinition(name: 't1', path: '/old', layerNames: ['A']),
      );
      await repo.saveThread(
        const ThreadDefinition(
          name: 't1',
          path: '/new',
          layerNames: ['A', 'B'],
          enabled: false,
        ),
      );

      final threads = await repo.listThreads();
      expect(threads, hasLength(1));
      expect(threads.first.path, '/new');
      expect(threads.first.layerNames, ['A', 'B']);
      expect(threads.first.enabled, false);
    });
  });

  group('task CRUD', () {
    test('createTask stores and retrieves a task', () async {
      final id = await repo.createTask('summarize', {
        'text': 'hello',
      }, TaskPriority.high);

      final task = await repo.getTask(id);
      expect(task, isNotNull);
      expect(task!.taskType, 'summarize');
      expect(task.payload, {'text': 'hello'});
      expect(task.priority, TaskPriority.high);
      expect(task.status, TaskStatus.pending);
    });

    test('listTasks returns saved tasks', () async {
      await repo.createTask('a', null, TaskPriority.low);
      await repo.createTask('b', [1, 2], TaskPriority.medium);

      final tasks = await repo.listTasks();
      expect(tasks, hasLength(2));
    });
  });
}
