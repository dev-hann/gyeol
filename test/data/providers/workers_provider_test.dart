import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/providers/core_providers.dart';
import 'package:gyeol/data/providers/workers_provider.dart';

class _ErrorInjectDb extends AppDatabase {
  _ErrorInjectDb(this.controller) : super.forTesting(NativeDatabase.memory());

  final StreamController<List<Worker>> controller;

  @override
  Stream<List<Worker>> watchWorkers() => controller.stream;
}

void main() {

  Future<int> _createThread(AppDatabase database) async {
    await database.saveThread(ThreadsCompanion.insert(name: 'default', path: '/tmp'));
    return (await database.getThread('default'))!.id;
  }

  late AppDatabase db;
  late ProviderContainer container;

  late int _tid;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    _tid = await _createThread(db);
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('WorkersNotifier', () {
    test('build returns empty list when no workers', () async {
      final workers = await container.read(workersProvider.future);
      expect(workers, isEmpty);
    });

    test('saveWorker adds worker and refreshes list', () async {
      final repo = container.read(repositoryProvider);
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

      final notifier = container.read(workersProvider.notifier);
      await notifier.saveWorker(
        WorkerDefinition(
          id: 0,
          name: 'parser',
          layerId: layers.first.id,
          systemPrompt: 'Parse the input',
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final workers = await container.read(workersProvider.future);
      expect(workers, hasLength(1));
      expect(workers.first.name, 'parser');
      expect(workers.first.layerId, layers.first.id);
      expect(workers.first.systemPrompt, 'Parse the input');
      expect(workers.first.enabled, isTrue);
    });

    test('saveWorker updates existing worker with same name', () async {
      final repo = container.read(repositoryProvider);
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

      final notifier = container.read(workersProvider.notifier);
      await notifier.saveWorker(
        WorkerDefinition(
          id: 0,
          name: 'parser',
          layerId: layerId,
          systemPrompt: 'Original',
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await notifier.saveWorker(
        WorkerDefinition(
          id: 0,
          name: 'parser',
          layerId: layerId,
          systemPrompt: 'Updated',
          model: 'gpt-4o',
          temperature: 0.7,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final workers = await container.read(workersProvider.future);
      expect(workers, hasLength(1));
      expect(workers.first.systemPrompt, 'Updated');
      expect(workers.first.model, 'gpt-4o');
      expect(workers.first.temperature, 0.7);
    });

    test('saveWorker stores multiple workers', () async {
      final repo = container.read(repositoryProvider);
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

      final notifier = container.read(workersProvider.notifier);
      await notifier.saveWorker(
        WorkerDefinition(
          id: 0,
          name: 'w1',
          layerId: layerId,
          systemPrompt: 'prompt 1',
        ),
      );
      await notifier.saveWorker(
        WorkerDefinition(
          id: 0,
          name: 'w2',
          layerId: layerId,
          systemPrompt: 'prompt 2',
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final workers = await container.read(workersProvider.future);
      expect(workers, hasLength(2));
      final names = workers.map((w) => w.name).toList();
      expect(names, containsAll(['w1', 'w2']));
    });

    test('deleteWorker removes worker and refreshes list', () async {
      final repo = container.read(repositoryProvider);
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

      final notifier = container.read(workersProvider.notifier);
      await notifier.saveWorker(
        WorkerDefinition(
          id: 0,
          name: 'temp-worker',
          layerId: layers.first.id,
          systemPrompt: 'temporary',
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final workers = await container.read(workersProvider.future);
      expect(workers, hasLength(1));

      await notifier.deleteWorker(workers.first.id);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final updated = await container.read(workersProvider.future);
      expect(updated, isEmpty);
    });

    test('deleteWorker no-op when id does not exist', () async {
      final repo = container.read(repositoryProvider);
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

      final notifier = container.read(workersProvider.notifier);
      await notifier.saveWorker(
        WorkerDefinition(
          id: 0,
          name: 'keep',
          layerId: layers.first.id,
          systemPrompt: 'keep me',
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await notifier.deleteWorker(9999);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final workers = await container.read(workersProvider.future);
      expect(workers, hasLength(1));
      expect(workers.first.name, 'keep');
    });

    test('stream error transitions state to AsyncError', () async {
      final controller = StreamController<List<Worker>>();
      final errDb = _ErrorInjectDb(controller);
      final errContainer = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(errDb)],
      );

      await errContainer.read(workersProvider.future);
      controller.addError(StateError('db broken'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = errContainer.read(workersProvider);
      expect(state.hasError, isTrue);

      await controller.close();
      errContainer.dispose();
      await errDb.close();
    });
  });
}
