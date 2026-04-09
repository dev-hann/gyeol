import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/repositories/app_repository.dart';
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
        name: 'empty',
        path: '/tmp',
        layerNames: [],
      );
      final results = await scheduler.runThread(thread);
      expect(results, isEmpty);
    });

    test('executes layers in sequence and returns results', () async {
      registry
        ..register(
          const LayerDefinition(
            name: 'L1',
            inputTypes: ['raw'],
            outputTypes: ['parsed'],
            workerNames: ['w1'],
            order: 1,
          ),
        )
        ..register(
          const LayerDefinition(
            name: 'L2',
            inputTypes: ['parsed'],
            outputTypes: ['done'],
            workerNames: ['w2'],
            order: 2,
          ),
        );

      await repo.saveWorker(
        const WorkerDefinition(
          name: 'w1',
          layerName: 'L1',
          systemPrompt: 'parse the input',
        ),
      );
      await repo.saveWorker(
        const WorkerDefinition(
          name: 'w2',
          layerName: 'L2',
          systemPrompt: 'analyze the parsed data',
        ),
      );
      await repo.saveSettings(
        const ProviderSettings(provider: ProviderType.ollama),
      );

      const thread = ThreadDefinition(
        name: 'test_thread',
        path: '/tmp/nonexistent_test_path',
        layerNames: ['L1', 'L2'],
      );

      final results = await scheduler.runThread(thread);

      expect(results, isNotEmpty);
    });

    test('skips disabled layers', () async {
      registry
        ..register(
          const LayerDefinition(
            name: 'L1',
            inputTypes: ['raw'],
            outputTypes: ['parsed'],
            workerNames: ['w1'],
            order: 1,
            enabled: false,
          ),
        )
        ..register(
          const LayerDefinition(
            name: 'L2',
            inputTypes: ['raw'],
            outputTypes: ['done'],
            workerNames: ['w2'],
            order: 2,
          ),
        );

      await repo.saveWorker(
        const WorkerDefinition(
          name: 'w2',
          layerName: 'L2',
          systemPrompt: 'run me',
        ),
      );
      await repo.saveSettings(
        const ProviderSettings(provider: ProviderType.ollama),
      );

      const thread = ThreadDefinition(
        name: 'skip_test',
        path: '/tmp',
        layerNames: ['L1', 'L2'],
      );

      final results = await scheduler.runThread(thread);
      expect(results.length, 1);
    });

    test('includes path context in task payload', () async {
      registry.register(
        const LayerDefinition(
          name: 'L1',
          inputTypes: ['raw'],
          outputTypes: ['parsed'],
          workerNames: ['w1'],
          order: 1,
        ),
      );

      await repo.saveWorker(
        const WorkerDefinition(
          name: 'w1',
          layerName: 'L1',
          systemPrompt: 'process files',
        ),
      );
      await repo.saveSettings(
        const ProviderSettings(provider: ProviderType.ollama),
      );

      const thread = ThreadDefinition(
        name: 'path_test',
        path: '/custom/workspace',
        layerNames: ['L1'],
      );

      await scheduler.runThread(thread);

      final logs = await repo.listExecutionLogs();
      expect(logs, isNotEmpty);
    });
  });

  group('runAllThreads', () {
    test('returns empty map when no threads provided', () async {
      final results = await scheduler.runAllThreads([]);
      expect(results, isEmpty);
    });

    test('executes multiple threads sequentially', () async {
      registry.register(
        const LayerDefinition(
          name: 'L1',
          inputTypes: ['raw'],
          outputTypes: ['done'],
          workerNames: ['w1'],
          order: 1,
        ),
      );

      await repo.saveWorker(
        const WorkerDefinition(
          name: 'w1',
          layerName: 'L1',
          systemPrompt: 'do work',
        ),
      );
      await repo.saveSettings(
        const ProviderSettings(provider: ProviderType.ollama),
      );

      const threads = [
        ThreadDefinition(name: 'thread1', path: '/path/a', layerNames: ['L1']),
        ThreadDefinition(name: 'thread2', path: '/path/b', layerNames: ['L1']),
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
