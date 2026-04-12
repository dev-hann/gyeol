import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/providers/core_providers.dart';
import 'package:gyeol/data/providers/layers_provider.dart';

class _ErrorInjectDb extends AppDatabase {
  _ErrorInjectDb(this.controller) : super.forTesting(NativeDatabase.memory());

  final StreamController<List<Layer>> controller;

  @override
  Stream<List<Layer>> watchLayers() => controller.stream;
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('LayersNotifier', () {
    test('build returns empty list when no layers', () async {
      final layers = await container.read(layersProvider.future);
      expect(layers, isEmpty);
    });

    test('saveLayer adds layer and refreshes list', () async {
      final notifier = container.read(layersProvider.notifier);
      await notifier.saveLayer(
        const LayerDefinition(
          id: 0,
          name: 'parse',
          inputTypes: ['text'],
          outputTypes: ['structured'],
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final layers = await container.read(layersProvider.future);
      expect(layers, hasLength(1));
      expect(layers.first.name, 'parse');
      expect(layers.first.inputTypes, ['text']);
      expect(layers.first.outputTypes, ['structured']);
      expect(layers.first.enabled, isTrue);
      expect(layers.first.order, 0);
    });

    test('saveLayer updates existing layer with same name', () async {
      final notifier = container.read(layersProvider.notifier);
      await notifier.saveLayer(
        const LayerDefinition(
          id: 0,
          name: 'parse',
          inputTypes: ['text'],
          outputTypes: [],
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final existing = await container.read(layersProvider.future);
      final existingId = existing.first.id;

      await notifier.saveLayer(
        LayerDefinition(
          id: existingId,
          name: 'parse',
          inputTypes: ['text', 'json'],
          outputTypes: ['structured'],
          layerPrompt: 'Parse input',
          order: 5,
          enabled: false,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final layers = await container.read(layersProvider.future);
      expect(layers, hasLength(1));
      expect(layers.first.inputTypes, ['text', 'json']);
      expect(layers.first.outputTypes, ['structured']);
      expect(layers.first.layerPrompt, 'Parse input');
      expect(layers.first.order, 5);
      expect(layers.first.enabled, isFalse);
    });

    test('saveLayer stores multiple layers', () async {
      final notifier = container.read(layersProvider.notifier);
      await notifier.saveLayer(
        const LayerDefinition(
          id: 0,
          name: 'parse',
          inputTypes: ['text'],
          outputTypes: ['structured'],
          order: 1,
        ),
      );
      await notifier.saveLayer(
        const LayerDefinition(
          id: 0,
          name: 'analyze',
          inputTypes: ['structured'],
          outputTypes: ['insight'],
          order: 2,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final layers = await container.read(layersProvider.future);
      expect(layers, hasLength(2));
      final names = layers.map((l) => l.name).toList();
      expect(names, containsAll(['parse', 'analyze']));
    });

    test('deleteLayer removes layer and refreshes list', () async {
      final notifier = container.read(layersProvider.notifier);
      await notifier.saveLayer(
        const LayerDefinition(
          id: 0,
          name: 'temp-layer',
          inputTypes: ['text'],
          outputTypes: [],
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final layers = await container.read(layersProvider.future);
      expect(layers, hasLength(1));

      await notifier.deleteLayer(layers.first.id);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final updated = await container.read(layersProvider.future);
      expect(updated, isEmpty);
    });

    test('deleteLayer no-op when id does not exist', () async {
      final notifier = container.read(layersProvider.notifier);
      await notifier.saveLayer(
        const LayerDefinition(
          id: 0,
          name: 'keep',
          inputTypes: ['text'],
          outputTypes: [],
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await notifier.deleteLayer(9999);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final layers = await container.read(layersProvider.future);
      expect(layers, hasLength(1));
      expect(layers.first.name, 'keep');
    });

    test('stream error transitions state to AsyncError', () async {
      final controller = StreamController<List<Layer>>();
      final errDb = _ErrorInjectDb(controller);
      final errContainer = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(errDb)],
      );

      await errContainer.read(layersProvider.future);
      controller.addError(StateError('db broken'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = errContainer.read(layersProvider);
      expect(state.hasError, isTrue);

      await controller.close();
      errContainer.dispose();
      await errDb.close();
    });
  });
}
