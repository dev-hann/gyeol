import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/models/layer_models.dart';
import 'package:gyeol/data/repositories/app_repository.dart';

void main() {  Future<int> _createThread(AppDatabase database) async {
    await database.saveThread(ThreadsCompanion.insert(name: 'default', path: '/tmp'));
    return (await database.getThread('default'))!.id;
  }

  late AppDatabase db;
  late AppRepository repo;

  late int _tid;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    _tid = await _createThread(db);
    repo = AppRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('LayerRepository saveLayer + listLayers', () {
    test('round-trips a layer with required fields only', () async {
      final layer = LayerDefinition(
        id: 0,
threadId: _tid,
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
      final layer = LayerDefinition(
        id: 0,
threadId: _tid,
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
      final third = LayerDefinition(
        id: 0,
threadId: _tid,
        name: 'c',
        inputTypes: [],
        outputTypes: [],
        order: 30,
      );
      final first = LayerDefinition(
        id: 0,
threadId: _tid,
        name: 'a',
        inputTypes: [],
        outputTypes: [],
        order: 10,
      );
      final second = LayerDefinition(
        id: 0,
threadId: _tid,
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
      final original = LayerDefinition(
        id: 0,
threadId: _tid,
        name: 'layer-x',
        inputTypes: ['raw'],
        outputTypes: ['parsed'],
        order: 1,
      );
      await repo.layers.saveLayer(original);

      final saved = await repo.layers.listLayers();
      final savedId = saved.first.id;

      final updated = LayerDefinition(
        id: savedId,
        threadId: _tid,
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
      final layer = LayerDefinition(
        id: 0,
threadId: _tid,
        name: 'to_delete',
        inputTypes: [],
        outputTypes: [],
      );
      await repo.layers.saveLayer(layer);
      expect(await repo.layers.listLayers(), hasLength(1));

      final saved = await repo.layers.listLayers();
      await repo.layers.deleteLayer(saved.first.id);
      expect(await repo.layers.listLayers(), isEmpty);
    });

    test('is no-op for non-existent layer', () async {
      await repo.layers.deleteLayer(999);

      final layers = await repo.layers.listLayers();
      expect(layers, isEmpty);
    });
  });

  group('LayerRepository watchLayers', () {
    test('emits update when layer is saved', () async {
      final stream = repo.layers.watchLayers();

      final firstEmission = await stream.first;
      expect(firstEmission, isEmpty);

      final layer = LayerDefinition(
        id: 0,
threadId: _tid,
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
      final l1 = LayerDefinition(
        id: 0,
threadId: _tid,
        name: 'parse',
        inputTypes: ['text'],
        outputTypes: ['structured'],
        order: 1,
      );
      final l2 = LayerDefinition(
        id: 0,
threadId: _tid,
        name: 'analyze',
        inputTypes: ['structured'],
        outputTypes: ['analysis'],
        order: 2,
      );
      final l3 = LayerDefinition(
        id: 0,
threadId: _tid,
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
      final keep = LayerDefinition(
        id: 0,
threadId: _tid,
        name: 'keep',
        inputTypes: [],
        outputTypes: [],
      );
      final remove = LayerDefinition(
        id: 0,
threadId: _tid,
        name: 'remove',
        inputTypes: [],
        outputTypes: [],
      );
      await repo.layers.saveLayer(keep);
      await repo.layers.saveLayer(remove);

      final saved = await repo.layers.listLayers();
      final removeLayer = saved.firstWhere((l) => l.name == 'remove');
      await repo.layers.deleteLayer(removeLayer.id);
      final layers = await repo.layers.listLayers();
      expect(layers, hasLength(1));
      expect(layers.first.name, 'keep');
    });
  });

  group('LayerRepository malformed data resilience', () {
    test('returns empty inputTypes when stored JSON is malformed', () async {
      await db.saveLayer(
        LayersCompanion.insert(
          threadId: _tid,
          name: 'bad-input',
          inputTypes: 'not-valid-json{{{',
          outputTypes: '["ok"]',
        ),
      );

      final layers = await repo.layers.listLayers();
      expect(layers, hasLength(1));
      expect(layers.first.name, 'bad-input');
      expect(layers.first.inputTypes, isEmpty);
      expect(layers.first.outputTypes, ['ok']);
    });

    test('returns empty outputTypes when stored JSON is malformed', () async {
      await db.saveLayer(
        LayersCompanion.insert(
          threadId: _tid,
          name: 'bad-output',
          inputTypes: '["text"]',
          outputTypes: '{"broken":true}',
        ),
      );

      final layers = await repo.layers.listLayers();
      expect(layers, hasLength(1));
      expect(layers.first.inputTypes, ['text']);
      expect(layers.first.outputTypes, isEmpty);
    });

    test('returns empty list when stored value is not a JSON array', () async {
      await db.saveLayer(
        LayersCompanion.insert(
          threadId: _tid,
          name: 'not-array',
          inputTypes: '"a_string"',
          outputTypes: '42',
        ),
      );

      final layers = await repo.layers.listLayers();
      expect(layers, hasLength(1));
      expect(layers.first.inputTypes, isEmpty);
      expect(layers.first.outputTypes, isEmpty);
    });

    test('filters non-string elements from stored list', () async {
      await db.saveLayer(
        LayersCompanion.insert(
          threadId: _tid,
          name: 'mixed-types',
          inputTypes: '["text", 42, true, "json"]',
          outputTypes: '[null, "analysis"]',
        ),
      );

      final layers = await repo.layers.listLayers();
      expect(layers, hasLength(1));
      expect(layers.first.inputTypes, ['text', 'json']);
      expect(layers.first.outputTypes, ['analysis']);
    });

    test('handles both fields corrupted gracefully', () async {
      await db.saveLayer(
        LayersCompanion.insert(
          threadId: _tid,
          name: 'both-bad',
          inputTypes: 'broken',
          outputTypes: '{invalid',
        ),
      );

      final layers = await repo.layers.listLayers();
      expect(layers, hasLength(1));
      expect(layers.first.name, 'both-bad');
      expect(layers.first.inputTypes, isEmpty);
      expect(layers.first.outputTypes, isEmpty);
    });
  });
}
