import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/repositories/app_repository.dart';
import 'package:gyeol/engine/queue/task_queue.dart';
import 'package:gyeol/engine/scheduler.dart';

void main() {
  group('LayerRegistry register', () {
    test('adds a layer', () {
      final registry = LayerRegistry();
      const layer = LayerDefinition(
        name: 'L1',
        inputTypes: ['text'],
        outputTypes: ['analysis'],
        workerNames: ['w1'],
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
            name: 'L1',
            inputTypes: ['text'],
            outputTypes: ['analysis'],
            workerNames: ['w1'],
            order: 1,
          ),
        )
        ..register(
          const LayerDefinition(
            name: 'L1',
            inputTypes: ['text', 'json'],
            outputTypes: ['analysis'],
            workerNames: ['w2'],
            order: 2,
          ),
        );

      final found = registry.findByInputType('text');
      expect(found, hasLength(1));
      expect(found.first.workerNames, ['w2']);
    });

    test('sorts by order ascending', () {
      final registry = LayerRegistry()
        ..register(
          const LayerDefinition(
            name: 'B',
            inputTypes: ['text'],
            outputTypes: [],
            workerNames: [],
            order: 2,
          ),
        )
        ..register(
          const LayerDefinition(
            name: 'A',
            inputTypes: ['text'],
            outputTypes: [],
            workerNames: [],
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
            name: 'L1',
            inputTypes: ['text'],
            outputTypes: [],
            workerNames: [],
          ),
        )
        ..remove('L1');

      expect(registry.findByInputType('text'), isEmpty);
    });

    test('no-op when name not found', () {
      final registry = LayerRegistry()
        ..register(
          const LayerDefinition(
            name: 'L1',
            inputTypes: ['text'],
            outputTypes: [],
            workerNames: [],
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
            name: 'old',
            inputTypes: ['text'],
            outputTypes: [],
            workerNames: [],
          ),
        )
        ..setAll([
          const LayerDefinition(
            name: 'new1',
            inputTypes: ['text'],
            outputTypes: [],
            workerNames: [],
            order: 2,
          ),
          const LayerDefinition(
            name: 'new2',
            inputTypes: ['text'],
            outputTypes: [],
            workerNames: [],
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
            name: 'enabled',
            inputTypes: ['text'],
            outputTypes: [],
            workerNames: [],
          ),
        )
        ..register(
          const LayerDefinition(
            name: 'disabled',
            inputTypes: ['text'],
            outputTypes: [],
            workerNames: [],
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
            name: 'L1',
            inputTypes: ['image'],
            outputTypes: [],
            workerNames: [],
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

      final task = AppTask.create('analysis', <String, dynamic>{
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

      final task = AppTask.create('translation', <String, dynamic>{
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
        <String, dynamic>{},
        TaskPriority.high,
      );
      final task2 = AppTask.create(
        'translation',
        <String, dynamic>{},
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
        <String, dynamic>{},
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
        <String, dynamic>{},
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

    test('returns task id and increments queueLength', () {
      final task = AppTask.create('text', {'k': 'v'}, TaskPriority.high);
      final id = scheduler.submit(task);
      expect(id, task.id);
      expect(scheduler.queueLength, 1);
    });

    test('accepts multiple tasks', () {
      scheduler
        ..submit(AppTask.create('a', null, TaskPriority.low))
        ..submit(AppTask.create('b', null, TaskPriority.high))
        ..submit(AppTask.create('c', null, TaskPriority.medium));
      expect(scheduler.queueLength, 3);
    });
  });

  group('Scheduler runOnce', () {
    late Scheduler scheduler;
    late TaskQueue queue;
    late LayerRegistry registry;
    late MessageBus bus;
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      queue = TaskQueue();
      registry = LayerRegistry();
      bus = MessageBus();
      scheduler = Scheduler(
        queue: queue,
        layerRegistry: registry,
        messageBus: bus,
        repo: AppRepository(db),
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
      scheduler.submit(AppTask.create('unknown_type', null, TaskPriority.high));
      final results = await scheduler.runOnce();
      expect(results, isEmpty);
      expect(scheduler.queueLength, 0);
    });

    test('skips task when depth exceeds maxExecutionDepth', () async {
      registry.register(
        const LayerDefinition(
          name: 'deep',
          inputTypes: ['deep'],
          outputTypes: [],
          workerNames: ['w1'],
        ),
      );
      final task = AppTask.create(
        'deep',
        null,
        TaskPriority.high,
      ).copyWith(depth: 11);
      scheduler.submit(task);
      final results = await scheduler.runOnce();
      expect(results, isEmpty);
      expect(scheduler.queueLength, 0);
    });

    test('skips task when all matching layers are disabled', () async {
      registry.register(
        const LayerDefinition(
          name: 'off',
          inputTypes: ['text'],
          outputTypes: [],
          workerNames: ['w1'],
          enabled: false,
        ),
      );
      scheduler.submit(AppTask.create('text', null, TaskPriority.high));
      final results = await scheduler.runOnce();
      expect(results, isEmpty);
    });

    test('returns failed result when worker not found', () async {
      registry.register(
        const LayerDefinition(
          name: 'L',
          inputTypes: ['text'],
          outputTypes: [],
          workerNames: ['missing_worker'],
        ),
      );

      scheduler.submit(
        AppTask.create('text', {'data': 'x'}, TaskPriority.high),
      );

      final results = await scheduler.runOnce();
      expect(results, hasLength(1));
      expect(results.first.success, false);
      expect(results.first.error, contains('missing_worker'));
      expect(scheduler.queueLength, 0);
    });

    test('drains queue after processing valid task', () async {
      registry.register(
        const LayerDefinition(
          name: 'L',
          inputTypes: ['text'],
          outputTypes: [],
          workerNames: ['w1'],
        ),
      );

      scheduler.submit(AppTask.create('text', null, TaskPriority.high));

      expect(scheduler.queueLength, 1);
      await scheduler.runOnce();
      expect(scheduler.queueLength, 0);
    });
  });
}
