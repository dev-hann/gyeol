import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/engine/scheduler.dart';

void main() {
  // ── LayerRegistry ──

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

  // ── MessageBus ──

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
}
