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

  group('ThreadRepository saveThread + getThread', () {
    test('round-trips a thread with required fields only', () async {
      await repo.layers.saveLayer(
        const LayerDefinition(
          id: 0,
          name: 'parse',
          inputTypes: ['text'],
          outputTypes: [],
        ),
      );
      await repo.layers.saveLayer(
        const LayerDefinition(
          id: 0,
          name: 'analyze',
          inputTypes: ['text'],
          outputTypes: [],
        ),
      );
      final layers = await repo.layers.listLayers();
      final parseId = layers.firstWhere((l) => l.name == 'parse').id;
      final analyzeId = layers.firstWhere((l) => l.name == 'analyze').id;
      final thread = ThreadDefinition(
        id: 0,
        name: 'pipeline-1',
        path: '/root/child',
        layerIds: [parseId, analyzeId],
      );
      await repo.threads.saveThread(thread);

      final found = await repo.threads.getThread('pipeline-1');
      expect(found, isNotNull);
      expect(found!.name, 'pipeline-1');
      expect(found.path, '/root/child');
      expect(found.layerIds, [parseId, analyzeId]);
      expect(found.contextPrompt, isNull);
      expect(found.enabled, true);
      expect(found.status, ThreadStatus.idle);
    });

    test('round-trips a thread with all optional fields', () async {
      await repo.layers.saveLayer(
        const LayerDefinition(
          id: 0,
          name: 'extract',
          inputTypes: ['text'],
          outputTypes: [],
        ),
      );
      await repo.layers.saveLayer(
        const LayerDefinition(
          id: 0,
          name: 'transform',
          inputTypes: ['text'],
          outputTypes: [],
        ),
      );
      await repo.layers.saveLayer(
        const LayerDefinition(
          id: 0,
          name: 'load',
          inputTypes: ['text'],
          outputTypes: [],
        ),
      );
      final layers = await repo.layers.listLayers();
      final extractId = layers.firstWhere((l) => l.name == 'extract').id;
      final transformId = layers.firstWhere((l) => l.name == 'transform').id;
      final loadId = layers.firstWhere((l) => l.name == 'load').id;
      final thread = ThreadDefinition(
        id: 0,
        name: 'pipeline-2',
        path: '/a/b/c',
        layerIds: [extractId, transformId, loadId],
        contextPrompt: 'Summarize the result',
        enabled: false,
        status: ThreadStatus.completed,
      );
      await repo.threads.saveThread(thread);

      final found = await repo.threads.getThread('pipeline-2');
      expect(found, isNotNull);
      expect(found!.name, 'pipeline-2');
      expect(found.path, '/a/b/c');
      expect(found.layerIds, [extractId, transformId, loadId]);
      expect(found.contextPrompt, 'Summarize the result');
      expect(found.enabled, false);
      expect(found.status, ThreadStatus.completed);
    });

    test('returns null for non-existent thread', () async {
      final found = await repo.threads.getThread('ghost');
      expect(found, isNull);
    });
  });

  group('ThreadRepository listThreads', () {
    test('returns empty list when no threads', () async {
      final threads = await repo.threads.listThreads();
      expect(threads, isEmpty);
    });

    test('returns all saved threads', () async {
      await repo.layers.saveLayer(
        const LayerDefinition(
          id: 0,
          name: 'L1',
          inputTypes: ['text'],
          outputTypes: [],
        ),
      );
      await repo.layers.saveLayer(
        const LayerDefinition(
          id: 0,
          name: 'L2',
          inputTypes: ['text'],
          outputTypes: [],
        ),
      );
      final layers = await repo.layers.listLayers();
      final l1Id = layers.firstWhere((l) => l.name == 'L1').id;
      final l2Id = layers.firstWhere((l) => l.name == 'L2').id;
      final t1 = ThreadDefinition(
        id: 0,
        name: 'alpha',
        path: '/a',
        layerIds: [l1Id],
      );
      final t2 = ThreadDefinition(
        id: 0,
        name: 'beta',
        path: '/b',
        layerIds: [l2Id],
      );
      await repo.threads.saveThread(t1);
      await repo.threads.saveThread(t2);

      final threads = await repo.threads.listThreads();
      expect(threads, hasLength(2));
      final names = threads.map((t) => t.name).toSet();
      expect(names, {'alpha', 'beta'});
    });
  });

  group('ThreadRepository deleteThread', () {
    test('removes a saved thread', () async {
      await repo.layers.saveLayer(
        const LayerDefinition(
          id: 0,
          name: 'L1',
          inputTypes: ['text'],
          outputTypes: [],
        ),
      );
      final layers = await repo.layers.listLayers();
      final layerId = layers.first.id;
      final thread = ThreadDefinition(
        id: 0,
        name: 'to_delete',
        path: '/x',
        layerIds: [layerId],
      );
      await repo.threads.saveThread(thread);
      expect(await repo.threads.getThread('to_delete'), isNotNull);

      final toDeleteThread = await repo.threads.getThread('to_delete');
      await repo.threads.deleteThread(toDeleteThread!.id);
      expect(await repo.threads.getThread('to_delete'), isNull);
    });

    test('is no-op for non-existent thread', () async {
      await repo.threads.deleteThread(99999);

      final threads = await repo.threads.listThreads();
      expect(threads, isEmpty);
    });
  });

  group('ThreadRepository watchThreads', () {
    test('emits update when thread is saved', () async {
      final stream = repo.threads.watchThreads();

      final firstEmission = await stream.first;
      expect(firstEmission, isEmpty);

      await repo.layers.saveLayer(
        const LayerDefinition(
          id: 0,
          name: 'L1',
          inputTypes: ['text'],
          outputTypes: [],
        ),
      );
      final layers = await repo.layers.listLayers();
      final layerId = layers.first.id;
      final thread = ThreadDefinition(
        id: 0,
        name: 'watched',
        path: '/w',
        layerIds: [layerId],
      );
      await repo.threads.saveThread(thread);

      final secondEmission = await stream.first;
      expect(secondEmission, hasLength(1));
      expect(secondEmission.first.name, 'watched');
    });
  });
}
