import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/models/app_models.dart';
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

  group('WorkerRepository saveWorker + getWorker', () {
    test('round-trips a worker with required fields only', () async {
      await repo.layers.saveLayer(
        LayerDefinition(
          id: 0,
threadId: _tid,
        name: 'parse',
          inputTypes: ['text'],
          outputTypes: [],
        ),
      );
      final layers = await repo.layers.listLayers();
      final layerId = layers.first.id;
      final worker = WorkerDefinition(
        id: 0,
        name: 'parser',
        layerId: layerId,
        systemPrompt: 'Parse the input',
      );
      await repo.workers.saveWorker(worker);

      final found = await repo.workers.getWorker('parser');
      expect(found, isNotNull);
      expect(found!.name, 'parser');
      expect(found.layerId, layerId);
      expect(found.systemPrompt, 'Parse the input');
      expect(found.model, isNull);
      expect(found.temperature, isNull);
      expect(found.maxTokens, isNull);
      expect(found.enabled, true);
    });

    test('round-trips a worker with all optional fields', () async {
      await repo.layers.saveLayer(
        LayerDefinition(
          id: 0,
threadId: _tid,
        name: 'analyze',
          inputTypes: ['text'],
          outputTypes: [],
        ),
      );
      final layers = await repo.layers.listLayers();
      final layerId = layers.first.id;
      final worker = WorkerDefinition(
        id: 0,
        name: 'analyzer',
        layerId: layerId,
        systemPrompt: 'Analyze deeply',
        model: 'gpt-4o',
        temperature: 0.7,
        maxTokens: 4096,
        enabled: false,
      );
      await repo.workers.saveWorker(worker);

      final found = await repo.workers.getWorker('analyzer');
      expect(found, isNotNull);
      expect(found!.name, 'analyzer');
      expect(found.layerId, layerId);
      expect(found.systemPrompt, 'Analyze deeply');
      expect(found.model, 'gpt-4o');
      expect(found.temperature, 0.7);
      expect(found.maxTokens, 4096);
      expect(found.enabled, false);
    });

    test('returns null for non-existent worker', () async {
      final found = await repo.workers.getWorker('ghost');
      expect(found, isNull);
    });
  });

  group('WorkerRepository listWorkers', () {
    test('returns empty list when no workers', () async {
      final workers = await repo.workers.listWorkers();
      expect(workers, isEmpty);
    });

    test('returns all saved workers', () async {
      await repo.layers.saveLayer(
        LayerDefinition(
          id: 0,
threadId: _tid,
        name: 'L1',
          inputTypes: ['text'],
          outputTypes: [],
        ),
      );
      await repo.layers.saveLayer(
        LayerDefinition(
          id: 0,
threadId: _tid,
        name: 'L2',
          inputTypes: ['text'],
          outputTypes: [],
        ),
      );
      final layers = await repo.layers.listLayers();
      final l1Id = layers.firstWhere((l) => l.name == 'L1').id;
      final l2Id = layers.firstWhere((l) => l.name == 'L2').id;
      final w1 = WorkerDefinition(
        id: 0,
        name: 'a',
        layerId: l1Id,
        systemPrompt: 'prompt a',
      );
      final w2 = WorkerDefinition(
        id: 0,
        name: 'b',
        layerId: l2Id,
        systemPrompt: 'prompt b',
      );
      await repo.workers.saveWorker(w1);
      await repo.workers.saveWorker(w2);

      final workers = await repo.workers.listWorkers();
      expect(workers, hasLength(2));
      final names = workers.map((w) => w.name).toSet();
      expect(names, {'a', 'b'});
    });
  });

  group('WorkerRepository deleteWorker', () {
    test('removes a saved worker', () async {
      await repo.layers.saveLayer(
        LayerDefinition(
          id: 0,
threadId: _tid,
        name: 'L1',
          inputTypes: ['text'],
          outputTypes: [],
        ),
      );
      final layers = await repo.layers.listLayers();
      final layerId = layers.first.id;
      final worker = WorkerDefinition(
        id: 0,
        name: 'to_delete',
        layerId: layerId,
        systemPrompt: 'delete me',
      );
      await repo.workers.saveWorker(worker);
      expect(await repo.workers.getWorker('to_delete'), isNotNull);

      final toDeleteWorker = await repo.workers.getWorker('to_delete');
      await repo.workers.deleteWorker(toDeleteWorker!.id);
      expect(await repo.workers.getWorker('to_delete'), isNull);
    });

    test('is no-op for non-existent worker', () async {
      await repo.workers.deleteWorker(99999);

      final workers = await repo.workers.listWorkers();
      expect(workers, isEmpty);
    });
  });

  group('WorkerRepository upsert', () {
    test('replaces existing worker with same name', () async {
      await repo.layers.saveLayer(
        LayerDefinition(
          id: 0,
threadId: _tid,
        name: 'L1',
          inputTypes: ['text'],
          outputTypes: [],
        ),
      );
      await repo.layers.saveLayer(
        LayerDefinition(
          id: 0,
threadId: _tid,
        name: 'L2',
          inputTypes: ['text'],
          outputTypes: [],
        ),
      );
      final layers = await repo.layers.listLayers();
      final l1Id = layers.firstWhere((l) => l.name == 'L1').id;
      final l2Id = layers.firstWhere((l) => l.name == 'L2').id;
      final original = WorkerDefinition(
        id: 0,
        name: 'upsert_w',
        layerId: l1Id,
        systemPrompt: 'original prompt',
        model: 'gpt-3.5',
        temperature: 0.5,
      );
      await repo.workers.saveWorker(original);

      final updated = WorkerDefinition(
        id: 0,
        name: 'upsert_w',
        layerId: l2Id,
        systemPrompt: 'updated prompt',
        model: 'gpt-4o',
        temperature: 0.9,
        maxTokens: 8192,
        enabled: false,
      );
      await repo.workers.saveWorker(updated);

      final found = await repo.workers.getWorker('upsert_w');
      expect(found, isNotNull);
      expect(found!.layerId, l2Id);
      expect(found.systemPrompt, 'updated prompt');
      expect(found.model, 'gpt-4o');
      expect(found.temperature, 0.9);
      expect(found.maxTokens, 8192);
      expect(found.enabled, false);

      final workers = await repo.workers.listWorkers();
      expect(workers, hasLength(1));
    });
  });

  group('WorkerRepository watchWorkers', () {
    test('emits update when worker is saved', () async {
      final stream = repo.workers.watchWorkers();

      final firstEmission = await stream.first;
      expect(firstEmission, isEmpty);

      await repo.layers.saveLayer(
        LayerDefinition(
          id: 0,
threadId: _tid,
        name: 'L1',
          inputTypes: ['text'],
          outputTypes: [],
        ),
      );
      final layers = await repo.layers.listLayers();
      final layerId = layers.first.id;
      final worker = WorkerDefinition(
        id: 0,
        name: 'watched',
        layerId: layerId,
        systemPrompt: 'watch me',
      );
      await repo.workers.saveWorker(worker);

      final secondEmission = await stream.first;
      expect(secondEmission, hasLength(1));
      expect(secondEmission.first.name, 'watched');
    });
  });
}
