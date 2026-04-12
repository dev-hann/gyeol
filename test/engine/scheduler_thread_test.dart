import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/repositories/app_repository.dart';
import 'package:gyeol/engine/layer_registry.dart';
import 'package:gyeol/engine/message_bus.dart';
import 'package:gyeol/engine/queue/task_queue.dart';
import 'package:gyeol/engine/scheduler.dart';

void main() {
  late Scheduler scheduler;
  late TaskQueue queue;
  late LayerRegistry registry;
  late MessageBus bus;
  late AppDatabase db;
  late AppRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = AppRepository(db);
    queue = TaskQueue();
    registry = LayerRegistry();
    bus = MessageBus();
    scheduler = Scheduler(
      queue: queue,
      layerRegistry: registry,
      messageBus: bus,
      repo: repo,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('runThread', () {
    test('returns empty when thread has no layers', () async {
      const thread = ThreadDefinition(
        id: 0,
        name: 'empty',
        path: '/tmp',
        layerIds: [],
      );
      final results = await scheduler.runThread(thread);
      expect(results, isEmpty);
    });

    test('executes layers in sequence and returns results', () async {
      await repo.layers.saveLayer(
        const LayerDefinition(
          id: 0,
          name: 'L1',
          inputTypes: ['raw'],
          outputTypes: ['parsed'],
          order: 1,
        ),
      );
      await repo.layers.saveLayer(
        const LayerDefinition(
          id: 0,
          name: 'L2',
          inputTypes: ['parsed'],
          outputTypes: ['done'],
          order: 2,
        ),
      );

      final savedLayers = await repo.layers.listLayers();
      final l1 = savedLayers.firstWhere((l) => l.name == 'L1');
      final l2 = savedLayers.firstWhere((l) => l.name == 'L2');

      registry
        ..register(l1)
        ..register(l2);

      await repo.workers.saveWorker(
        WorkerDefinition(
          id: 1,
          name: 'w1',
          layerId: l1.id,
          systemPrompt: 'parse the input',
        ),
      );
      await repo.workers.saveWorker(
        WorkerDefinition(
          id: 2,
          name: 'w2',
          layerId: l2.id,
          systemPrompt: 'analyze the parsed data',
        ),
      );
      await repo.settings.saveSettings(
        const ProviderSettings(
          activeProvider: ProviderType.ollama,
          configs: {
            ProviderType.openAI: OpenAIConfig(),
            ProviderType.anthropic: AnthropicConfig(),
            ProviderType.ollama: OllamaConfig(
              baseUrl: 'http://localhost:11434',
            ),
            ProviderType.custom: CustomConfig(),
          },
        ),
      );

      final thread = ThreadDefinition(
        id: 0,
        name: 'test_thread',
        path: '/tmp/nonexistent_test_path',
        layerIds: [l1.id, l2.id],
      );

      final results = await scheduler.runThread(thread);

      expect(results, isNotEmpty);
    });

    test('skips disabled layers', () async {
      await repo.layers.saveLayer(
        const LayerDefinition(
          id: 0,
          name: 'L1',
          inputTypes: ['raw'],
          outputTypes: ['parsed'],
          order: 1,
          enabled: false,
        ),
      );
      await repo.layers.saveLayer(
        const LayerDefinition(
          id: 0,
          name: 'L2',
          inputTypes: ['raw'],
          outputTypes: ['done'],
          order: 2,
        ),
      );

      final savedLayers = await repo.layers.listLayers();
      final l1 = savedLayers.firstWhere((l) => l.name == 'L1');
      final l2 = savedLayers.firstWhere((l) => l.name == 'L2');

      registry
        ..register(l1)
        ..register(l2);

      await repo.workers.saveWorker(
        WorkerDefinition(
          id: 0,
          name: 'w2',
          layerId: l2.id,
          systemPrompt: 'run me',
        ),
      );
      await repo.settings.saveSettings(
        const ProviderSettings(
          activeProvider: ProviderType.ollama,
          configs: {
            ProviderType.openAI: OpenAIConfig(),
            ProviderType.anthropic: AnthropicConfig(),
            ProviderType.ollama: OllamaConfig(
              baseUrl: 'http://localhost:11434',
            ),
            ProviderType.custom: CustomConfig(),
          },
        ),
      );

      final thread = ThreadDefinition(
        id: 0,
        name: 'skip_test',
        path: '/tmp',
        layerIds: [l1.id, l2.id],
      );

      final results = await scheduler.runThread(thread);
      expect(results.length, 1);
    });

    test('includes path context in task payload', () async {
      await repo.layers.saveLayer(
        const LayerDefinition(
          id: 0,
          name: 'L1',
          inputTypes: ['raw'],
          outputTypes: ['parsed'],
          order: 1,
        ),
      );

      final savedLayers = await repo.layers.listLayers();
      final l1 = savedLayers.firstWhere((l) => l.name == 'L1');

      registry.register(l1);

      await repo.workers.saveWorker(
        WorkerDefinition(
          id: 4,
          name: 'w1',
          layerId: l1.id,
          systemPrompt: 'process files',
        ),
      );
      await repo.settings.saveSettings(
        const ProviderSettings(
          activeProvider: ProviderType.ollama,
          configs: {
            ProviderType.openAI: OpenAIConfig(),
            ProviderType.anthropic: AnthropicConfig(),
            ProviderType.ollama: OllamaConfig(
              baseUrl: 'http://localhost:11434',
            ),
            ProviderType.custom: CustomConfig(),
          },
        ),
      );

      final thread = ThreadDefinition(
        id: 0,
        name: 'path_test',
        path: '/custom/workspace',
        layerIds: [l1.id],
      );

      await scheduler.runThread(thread);

      final logs = await repo.logs.listExecutionLogs();
      expect(logs, isNotEmpty);
    });
  });

  group('runAllThreads', () {
    test('returns empty map when no threads provided', () async {
      final results = await scheduler.runAllThreads([]);
      expect(results, isEmpty);
    });

    test('executes multiple threads sequentially', () async {
      await repo.layers.saveLayer(
        const LayerDefinition(
          id: 0,
          name: 'L1',
          inputTypes: ['raw'],
          outputTypes: ['done'],
          order: 1,
        ),
      );

      final savedLayers = await repo.layers.listLayers();
      final l1 = savedLayers.firstWhere((l) => l.name == 'L1');

      registry.register(l1);

      await repo.workers.saveWorker(
        WorkerDefinition(
          id: 0,
          name: 'w1',
          layerId: l1.id,
          systemPrompt: 'do work',
        ),
      );
      await repo.settings.saveSettings(
        const ProviderSettings(
          activeProvider: ProviderType.ollama,
          configs: {
            ProviderType.openAI: OpenAIConfig(),
            ProviderType.anthropic: AnthropicConfig(),
            ProviderType.ollama: OllamaConfig(
              baseUrl: 'http://localhost:11434',
            ),
            ProviderType.custom: CustomConfig(),
          },
        ),
      );

      final threads = [
        ThreadDefinition(
          id: 0,
          name: 'thread1',
          path: '/path/a',
          layerIds: [l1.id],
        ),
        ThreadDefinition(
          id: 0,
          name: 'thread2',
          path: '/path/b',
          layerIds: [l1.id],
        ),
      ];

      final results = await scheduler.runAllThreads(threads);
      expect(results, hasLength(2));
      expect(results.keys, containsAll(['thread1', 'thread2']));
    });
  });

  group('collectFilesFromPath', () {
    test('returns empty list for non-existent directory', () async {
      final files = await Scheduler.collectFilesFromPath('/nonexistent_dir');
      expect(files, isEmpty);
    });

    test('collects dart files from a directory', () async {
      final dir = Directory.systemTemp.createTempSync('gyeol_test_');
      File('${dir.path}/a.dart').writeAsStringSync('void main() {}');
      File('${dir.path}/b.txt').writeAsStringSync('text');
      File('${dir.path}/c.dart').writeAsStringSync('void other() {}');

      try {
        final files = await Scheduler.collectFilesFromPath(
          dir.path,
          extensions: ['.dart'],
        );
        expect(files, hasLength(2));
        expect(files.every((f) => f.endsWith('.dart')), true);
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });
}
