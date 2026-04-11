import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/models/worker_models.dart';
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

  group('WorkerRepository saveWorker + getWorker', () {
    test('round-trips a worker with required fields only', () async {
      const worker = WorkerDefinition(
        name: 'parser',
        layerName: 'parse',
        systemPrompt: 'Parse the input',
      );
      await repo.workers.saveWorker(worker);

      final found = await repo.workers.getWorker('parser');
      expect(found, isNotNull);
      expect(found!.name, 'parser');
      expect(found.layerName, 'parse');
      expect(found.systemPrompt, 'Parse the input');
      expect(found.model, isNull);
      expect(found.temperature, isNull);
      expect(found.maxTokens, isNull);
      expect(found.enabled, true);
    });

    test('round-trips a worker with all optional fields', () async {
      const worker = WorkerDefinition(
        name: 'analyzer',
        layerName: 'analyze',
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
      expect(found.layerName, 'analyze');
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
      const w1 = WorkerDefinition(
        name: 'a',
        layerName: 'L1',
        systemPrompt: 'prompt a',
      );
      const w2 = WorkerDefinition(
        name: 'b',
        layerName: 'L2',
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
      const worker = WorkerDefinition(
        name: 'to_delete',
        layerName: 'L1',
        systemPrompt: 'delete me',
      );
      await repo.workers.saveWorker(worker);
      expect(await repo.workers.getWorker('to_delete'), isNotNull);

      await repo.workers.deleteWorker('to_delete');
      expect(await repo.workers.getWorker('to_delete'), isNull);
    });

    test('is no-op for non-existent worker', () async {
      await repo.workers.deleteWorker('nonexistent');

      final workers = await repo.workers.listWorkers();
      expect(workers, isEmpty);
    });
  });

  group('WorkerRepository upsert', () {
    test('replaces existing worker with same name', () async {
      const original = WorkerDefinition(
        name: 'upsert_w',
        layerName: 'L1',
        systemPrompt: 'original prompt',
        model: 'gpt-3.5',
        temperature: 0.5,
      );
      await repo.workers.saveWorker(original);

      const updated = WorkerDefinition(
        name: 'upsert_w',
        layerName: 'L2',
        systemPrompt: 'updated prompt',
        model: 'gpt-4o',
        temperature: 0.9,
        maxTokens: 8192,
        enabled: false,
      );
      await repo.workers.saveWorker(updated);

      final found = await repo.workers.getWorker('upsert_w');
      expect(found, isNotNull);
      expect(found!.layerName, 'L2');
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

      const worker = WorkerDefinition(
        name: 'watched',
        layerName: 'L1',
        systemPrompt: 'watch me',
      );
      await repo.workers.saveWorker(worker);

      final secondEmission = await stream.first;
      expect(secondEmission, hasLength(1));
      expect(secondEmission.first.name, 'watched');
    });
  });
}
