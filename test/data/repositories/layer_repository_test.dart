import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/models/layer_models.dart';
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

  group('LayerRepository saveLayer + listLayers', () {
    test('round-trips a layer with required fields only', () async {
      const layer = LayerDefinition(
        name: 'parse',
        inputTypes: ['text'],
        outputTypes: ['structured'],
      );
      await repo.layers.saveLayer(layer);

      final layers = await repo.layers.listLayers();
      expect(layers, hasLength(1));
      expect(layers.first.name, 'parse');
      expect(layers.first.inputTypes, ['text']);
      expect(layers.first.outputTypes, ['structured']);
      expect(layers.first.layerPrompt, isNull);
      expect(layers.first.order, 0);
      expect(layers.first.enabled, true);
    });

    test('round-trips a layer with all optional fields', () async {
      const layer = LayerDefinition(
        name: 'analyze',
        inputTypes: ['structured'],
        outputTypes: ['analysis'],
        layerPrompt: 'Analyze the data',
        order: 5,
        enabled: false,
      );
      await repo.layers.saveLayer(layer);

      final layers = await repo.layers.listLayers();
      expect(layers, hasLength(1));
      final found = layers.first;
      expect(found.name, 'analyze');
      expect(found.inputTypes, ['structured']);
      expect(found.outputTypes, ['analysis']);
      expect(found.layerPrompt, 'Analyze the data');
      expect(found.order, 5);
      expect(found.enabled, false);
    });

    test('returns layers ordered by sortOrder ascending', () async {
      const third = LayerDefinition(
        name: 'c',
        inputTypes: [],
        outputTypes: [],
        order: 30,
      );
      const first = LayerDefinition(
        name: 'a',
        inputTypes: [],
        outputTypes: [],
        order: 10,
      );
      const second = LayerDefinition(
        name: 'b',
        inputTypes: [],
        outputTypes: [],
        order: 20,
      );
      await repo.layers.saveLayer(third);
      await repo.layers.saveLayer(first);
      await repo.layers.saveLayer(second);

      final layers = await repo.layers.listLayers();
      expect(layers.map((l) => l.name), ['a', 'b', 'c']);
    });

    test('returns empty list when no layers', () async {
      final layers = await repo.layers.listLayers();
      expect(layers, isEmpty);
    });
  });

  group('LayerRepository upsert', () {
    test('replaces existing layer with same name', () async {
      const original = LayerDefinition(
        name: 'layer-x',
        inputTypes: ['raw'],
        outputTypes: ['parsed'],
        order: 1,
      );
      await repo.layers.saveLayer(original);

      const updated = LayerDefinition(
        name: 'layer-x',
        inputTypes: ['raw', 'semi'],
        outputTypes: ['parsed', 'enriched'],
        layerPrompt: 'New prompt',
        order: 99,
        enabled: false,
      );
      await repo.layers.saveLayer(updated);

      final layers = await repo.layers.listLayers();
      expect(layers, hasLength(1));
      expect(layers.first.inputTypes, ['raw', 'semi']);
      expect(layers.first.outputTypes, ['parsed', 'enriched']);
      expect(layers.first.layerPrompt, 'New prompt');
      expect(layers.first.order, 99);
      expect(layers.first.enabled, false);
    });
  });

  group('LayerRepository deleteLayer', () {
    test('removes a saved layer', () async {
      const layer = LayerDefinition(
        name: 'to_delete',
        inputTypes: [],
        outputTypes: [],
      );
      await repo.layers.saveLayer(layer);
      expect(await repo.layers.listLayers(), hasLength(1));

      await repo.layers.deleteLayer('to_delete');
      expect(await repo.layers.listLayers(), isEmpty);
    });

    test('is no-op for non-existent layer', () async {
      await repo.layers.deleteLayer('nonexistent');

      final layers = await repo.layers.listLayers();
      expect(layers, isEmpty);
    });
  });

  group('LayerRepository watchLayers', () {
    test('emits update when layer is saved', () async {
      final stream = repo.layers.watchLayers();

      final firstEmission = await stream.first;
      expect(firstEmission, isEmpty);

      const layer = LayerDefinition(
        name: 'watched',
        inputTypes: ['text'],
        outputTypes: ['tokens'],
      );
      await repo.layers.saveLayer(layer);

      final secondEmission = await stream.first;
      expect(secondEmission, hasLength(1));
      expect(secondEmission.first.name, 'watched');
    });
  });

  group('LayerRepository multiple layers', () {
    test('saves and lists multiple layers', () async {
      const l1 = LayerDefinition(
        name: 'parse',
        inputTypes: ['text'],
        outputTypes: ['structured'],
        order: 1,
      );
      const l2 = LayerDefinition(
        name: 'analyze',
        inputTypes: ['structured'],
        outputTypes: ['analysis'],
        order: 2,
      );
      const l3 = LayerDefinition(
        name: 'generate',
        inputTypes: ['analysis'],
        outputTypes: ['text'],
        order: 3,
      );
      await repo.layers.saveLayer(l1);
      await repo.layers.saveLayer(l2);
      await repo.layers.saveLayer(l3);

      final layers = await repo.layers.listLayers();
      expect(layers, hasLength(3));
      expect(layers.map((l) => l.name), ['parse', 'analyze', 'generate']);
    });

    test('delete one layer preserves others', () async {
      const keep = LayerDefinition(
        name: 'keep',
        inputTypes: [],
        outputTypes: [],
      );
      const remove = LayerDefinition(
        name: 'remove',
        inputTypes: [],
        outputTypes: [],
      );
      await repo.layers.saveLayer(keep);
      await repo.layers.saveLayer(remove);

      await repo.layers.deleteLayer('remove');
      final layers = await repo.layers.listLayers();
      expect(layers, hasLength(1));
      expect(layers.first.name, 'keep');
    });
  });
}
