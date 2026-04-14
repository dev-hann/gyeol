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
  Future<int> _createThread(AppDatabase database) async {
    await database.saveThread(
      ThreadsCompanion.insert(name: 'default', path: '/tmp'),
    );
    return (await database.getThread('default'))!.id;
  }

  group('LayerRegistry register', () {
    test('adds a layer', () {
      final registry = LayerRegistry();
      const layer = const LayerDefinition(
        id: 0,
        threadId: 1,
        name: 'L1',
        inputTypes: ['text'],
        outputTypes: ['analysis'],
        order: 1,
      );
      registry.register(layer);

      final found = registry.findByInputType('text');
      expect(found, hasLength(1));
      expect(found.first.name, 'L1');
    });

    test('replaces existing layer with same name', () {
      final registry = LayerRegistry()
        ..register(
          const LayerDefinition(
            id: 0,
            threadId: 1,
            name: 'L1',
            inputTypes: ['text'],
            outputTypes: ['analysis'],
            order: 1,
          ),
        )
        ..register(
          const LayerDefinition(
            id: 0,
            threadId: 1,
            name: 'L1',
            inputTypes: ['text', 'json'],
            outputTypes: ['analysis'],
            order: 2,
          ),
        );

      final found = registry.findByInputType('text');
      expect(found, hasLength(1));
      expect(found.first.outputTypes, ['analysis']);
    });

    test('sorts by order ascending', () {
      final registry = LayerRegistry()
        ..register(
          const LayerDefinition(
            id: 0,
            threadId: 1,
            name: 'B',
            inputTypes: ['text'],
            outputTypes: [],
            order: 2,
          ),
        )
        ..register(
          const LayerDefinition(
            id: 0,
            threadId: 1,
            name: 'A',
            inputTypes: ['text'],
            outputTypes: [],
            order: 1,
          ),
        );

      final found = registry.findByInputType('text');
      expect(found.first.name, 'A');
      expect(found.last.name, 'B');
    });
  });

  group('LayerRegistry remove', () {
    test('removes layer by name', () {
      final registry = LayerRegistry()
        ..register(
          const LayerDefinition(
            id: 0,
            threadId: 1,
            name: 'L1',
            inputTypes: ['text'],
            outputTypes: [],
          ),
        )
        ..remove('L1');

      expect(registry.findByInputType('text'), isEmpty);
    });

    test('no-op when name not found', () {
      final registry = LayerRegistry()
        ..register(
          const LayerDefinition(
            id: 0,
            threadId: 1,
            name: 'L1',
            inputTypes: ['text'],
            outputTypes: [],
          ),
        )
        ..remove('nonexistent');

      expect(registry.findByInputType('text'), hasLength(1));
    });
  });

  group('LayerRegistry setAll', () {
    test('replaces all layers', () {
      final registry = LayerRegistry()
        ..register(
          const LayerDefinition(
            id: 0,
            threadId: 1,
            name: 'old',
            inputTypes: ['text'],
            outputTypes: [],
          ),
        )
        ..setAll([
          const LayerDefinition(
            id: 0,
            threadId: 1,
            name: 'new1',
            inputTypes: ['text'],
            outputTypes: [],
            order: 2,
          ),
          const LayerDefinition(
            id: 0,
            threadId: 1,
            name: 'new2',
            inputTypes: ['text'],
            outputTypes: [],
            order: 1,
          ),
        ]);

      final found = registry.findByInputType('text');
      expect(found, hasLength(2));
      expect(found[0].name, 'new2');
      expect(found[1].name, 'new1');
    });
  });

  group('LayerRegistry findByInputType', () {
    test('filters by enabled', () {
      final registry = LayerRegistry()
        ..register(
          const LayerDefinition(
            id: 0,
            threadId: 1,
            name: 'enabled',
            inputTypes: ['text'],
            outputTypes: [],
          ),
        )
        ..register(
          const LayerDefinition(
            id: 0,
            threadId: 1,
            name: 'disabled',
            inputTypes: ['text'],
            outputTypes: [],
            enabled: false,
          ),
        );

      final found = registry.findByInputType('text');
      expect(found, hasLength(1));
      expect(found.first.name, 'enabled');
    });

    test('returns empty for no match', () {
      final registry = LayerRegistry()
        ..register(
          const LayerDefinition(
            id: 0,
            threadId: 1,
            name: 'L1',
            inputTypes: ['image'],
            outputTypes: [],
          ),
        );

      expect(registry.findByInputType('text'), isEmpty);
    });
  });

  group('MessageBus publish', () {
    test('calls subscriber matching taskType', () {
      final bus = MessageBus();
      final received = <AppTask>[];
      bus.subscribe('analysis', received.add);

      final task = AppTask.create('analysis', const <String, dynamic>{
        'k': 'v',
      }, TaskPriority.high);
      bus.publish(task);

      expect(received, hasLength(1));
      expect(received.first.id, task.id);
    });

    test('does not call non-matching subscriber', () {
      final bus = MessageBus();
      final received = <AppTask>[];
      bus.subscribe('analysis', received.add);

      final task = AppTask.create('translation', const <String, dynamic>{
        'k': 'v',
      }, TaskPriority.low);
      bus.publish(task);

      expect(received, isEmpty);
    });

    test('calls wildcard subscriber for any taskType', () {
      final bus = MessageBus();
      final received = <AppTask>[];
      bus.subscribe('*', received.add);

      final task1 = AppTask.create(
        'analysis',
        const <String, dynamic>{},
        TaskPriority.high,
      );
      final task2 = AppTask.create(
        'translation',
        const <String, dynamic>{},
        TaskPriority.low,
      );
      bus
        ..publish(task1)
        ..publish(task2);

      expect(received, hasLength(2));
    });

    test('calls both specific and wildcard subscribers', () {
      final specificReceived = <AppTask>[];
      final wildcardReceived = <AppTask>[];
      final bus = MessageBus()
        ..subscribe('analysis', specificReceived.add)
        ..subscribe('*', wildcardReceived.add);

      final task = AppTask.create(
        'analysis',
        const <String, dynamic>{},
        TaskPriority.medium,
      );
      bus.publish(task);

      expect(specificReceived, hasLength(1));
      expect(wildcardReceived, hasLength(1));
    });

    test('supports multiple subscribers for same type', () {
      final received1 = <AppTask>[];
      final received2 = <AppTask>[];
      final bus = MessageBus()
        ..subscribe('analysis', received1.add)
        ..subscribe('analysis', received2.add);

      final task = AppTask.create(
        'analysis',
        const <String, dynamic>{},
        TaskPriority.high,
      );
      bus.publish(task);

      expect(received1, hasLength(1));
      expect(received2, hasLength(1));
    });
  });

  group('Scheduler submit', () {
    late Scheduler scheduler;
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      scheduler = Scheduler(
        queue: TaskQueue(),
        layerRegistry: LayerRegistry(),
        messageBus: MessageBus(),
        repo: AppRepository(db),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('returns task id and increments queueLength', () async {
      final task = AppTask.create('text', const {'k': 'v'}, TaskPriority.high);
      final id = await scheduler.submit(task);
      expect(id, greaterThan(0));
      expect(scheduler.queueLength, 1);
    });

    test('accepts multiple tasks', () async {
      await scheduler.submit(AppTask.create('a', null, TaskPriority.low));
      await scheduler.submit(AppTask.create('b', null, TaskPriority.high));
      await scheduler.submit(AppTask.create('c', null, TaskPriority.medium));
      expect(scheduler.queueLength, 3);
    });
  });

  group('Scheduler runOnce', () {
    late Scheduler scheduler;
    late TaskQueue queue;
    late LayerRegistry registry;
    late MessageBus bus;
    late AppDatabase db;
    late AppRepository repo;
    late int _tid;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      queue = TaskQueue();
      registry = LayerRegistry();
      bus = MessageBus();
      repo = AppRepository(db);
      _tid = await _createThread(db);
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

    test('returns empty when queue is empty', () async {
      final results = await scheduler.runOnce();
      expect(results, isEmpty);
    });

    test('skips task with no matching layer and drains it', () async {
      await scheduler.submit(
        AppTask.create('unknown_type', null, TaskPriority.high),
      );
      final results = await scheduler.runOnce();
      expect(results, isEmpty);
      expect(scheduler.queueLength, 0);
    });

    test('skips task when depth exceeds maxExecutionDepth', () async {
      registry.register(
        LayerDefinition(
          id: 0,
          threadId: _tid,
          name: 'deep',
          inputTypes: ['deep'],
          outputTypes: [],
        ),
      );
      final task = AppTask.create(
        'deep',
        null,
        TaskPriority.high,
      ).copyWith(depth: 11);
      await scheduler.submit(task);
      final results = await scheduler.runOnce();
      expect(results, isEmpty);
      expect(scheduler.queueLength, 0);
    });

    test('skips task when all matching layers are disabled', () async {
      registry.register(
        LayerDefinition(
          id: 0,
          threadId: _tid,
          name: 'off',
          inputTypes: ['text'],
          outputTypes: [],
          enabled: false,
        ),
      );
      await scheduler.submit(AppTask.create('text', null, TaskPriority.high));
      final results = await scheduler.runOnce();
      expect(results, isEmpty);
    });

    test('drains queue when layer has no workers in db', () async {
      await repo.layers.saveLayer(
        LayerDefinition(
          id: 0,
          threadId: _tid,
          name: 'L',
          inputTypes: ['text'],
          outputTypes: [],
        ),
      );
      final savedLayers = await repo.layers.listLayers();
      final savedLayer = savedLayers.first;

      registry.register(savedLayer);

      await scheduler.submit(AppTask.create('text', null, TaskPriority.high));

      expect(scheduler.queueLength, 1);
      await scheduler.runOnce();
      expect(scheduler.queueLength, 0);
    });

    test('marks task as failed when layer has no workers', () async {
      await repo.layers.saveLayer(
        LayerDefinition(
          id: 0,
          threadId: _tid,
          name: 'L',
          inputTypes: ['text'],
          outputTypes: [],
        ),
      );
      final savedLayers = await repo.layers.listLayers();
      registry.register(savedLayers.first);

      final id = await scheduler.submit(
        AppTask.create('text', null, TaskPriority.high),
      );

      await scheduler.runOnce();

      final tasks = await repo.tasks.listTasks();
      final task = tasks.firstWhere((t) => t.id == id);
      expect(task.status, TaskStatus.failed);
    });

    test('drains queue and processes task with db workers', () async {
      await repo.layers.saveLayer(
        LayerDefinition(
          id: 0,
          threadId: _tid,
          name: 'L',
          inputTypes: ['text'],
          outputTypes: [],
        ),
      );
      final savedLayers = await repo.layers.listLayers();
      final savedLayer = savedLayers.first;

      registry.register(savedLayer);

      await repo.workers.saveWorker(
        WorkerDefinition(
          id: 1,
          name: 'w1',
          layerId: savedLayer.id,
          systemPrompt: 'test',
        ),
      );

      await scheduler.submit(AppTask.create('text', null, TaskPriority.high));
      expect(scheduler.queueLength, 1);

      final results = await scheduler.runOnce();
      expect(scheduler.queueLength, 0);
      expect(results, isNotEmpty);
    });

    test('runOnce handles Error subtypes gracefully', () async {
      await repo.layers.saveLayer(
        LayerDefinition(
          id: 0,
          threadId: _tid,
          name: 'L',
          inputTypes: ['text'],
          outputTypes: [],
        ),
      );
      final savedLayers = await repo.layers.listLayers();
      final savedLayer = savedLayers.first;
      registry.register(savedLayer);

      await repo.workers.saveWorker(
        WorkerDefinition(
          id: 1,
          name: 'w1',
          layerId: savedLayer.id,
          systemPrompt: 'test',
        ),
      );

      await repo.settings.saveSettings(
        const ProviderSettings(configs: {ProviderType.openAI: OpenAIConfig()}),
      );

      await scheduler.submit(AppTask.create('text', null, TaskPriority.high));

      final results = await scheduler.runOnce();
      expect(results, hasLength(1));
      expect(results.first.success, isFalse);
      expect(results.first.error, contains('not configured'));
    });

    test(
      'runOnce catches LlmError from unconfigured Ollama provider',
      () async {
        await repo.layers.saveLayer(
          LayerDefinition(
            id: 0,
            threadId: _tid,
            name: 'L',
            inputTypes: ['text'],
            outputTypes: [],
          ),
        );
        final savedLayers = await repo.layers.listLayers();
        final savedLayer = savedLayers.first;
        registry.register(savedLayer);

        await repo.workers.saveWorker(
          WorkerDefinition(
            id: 1,
            name: 'w1',
            layerId: savedLayer.id,
            systemPrompt: 'test',
          ),
        );

        await repo.settings.saveSettings(
          const ProviderSettings(activeProvider: ProviderType.ollama),
        );

        await scheduler.submit(AppTask.create('text', null, TaskPriority.high));

        final results = await scheduler.runOnce();
        expect(results, hasLength(1));
        expect(results.first.success, isFalse);
        expect(results.first.error, isNotNull);
      },
    );
  });
}
