import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/models/layer_models.dart';
import 'package:gyeol/data/providers/connections_provider.dart';
import 'package:gyeol/data/providers/core_providers.dart';
import 'package:gyeol/data/repositories/app_repository.dart';

class _ErrorInjectDb extends AppDatabase {
  _ErrorInjectDb(this.controller) : super.forTesting(NativeDatabase.memory());

  final StreamController<List<LayerConnection>> controller;

  @override
  Stream<List<LayerConnection>> watchConnections() => controller.stream;
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

  Future<int> insertLayer(String name) async {
    const layer = LayerDefinition(
      id: 0,
      name: '',
      inputTypes: [],
      outputTypes: [],
    );
    final repo = AppRepository(db);
    await repo.layers.saveLayer(layer.copyWith(name: name));
    final layers = await repo.layers.listLayers();
    return layers.firstWhere((l) => l.name == name).id;
  }

  group('ConnectionsNotifier', () {
    test('build returns empty list when no connections', () async {
      final connections = await container.read(connectionsProvider.future);
      expect(connections, isEmpty);
    });

    test('build returns saved connections', () async {
      final srcId = await insertLayer('source');
      final dstId = await insertLayer('target');
      final repo = AppRepository(db);
      await repo.connections.saveConnection(
        LayerConnectionData(sourceLayerId: srcId, targetLayerId: dstId),
      );

      final connections = await container.read(connectionsProvider.future);
      expect(connections, hasLength(1));
      expect(connections.first.sourceLayerId, srcId);
      expect(connections.first.targetLayerId, dstId);
    });

    test('saveConnection persists connection', () async {
      final notifier = container.read(connectionsProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final srcId = await insertLayer('source');
      final dstId = await insertLayer('target');

      await notifier.saveConnection(
        LayerConnectionData(sourceLayerId: srcId, targetLayerId: dstId),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));

      container.invalidate(connectionsProvider);
      final connections = await container.read(connectionsProvider.future);
      expect(connections, hasLength(1));
    });

    test('deleteConnection removes connection', () async {
      final notifier = container.read(connectionsProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final a = await insertLayer('a');
      final b = await insertLayer('b');
      final c = await insertLayer('c');

      await notifier.saveConnection(
        LayerConnectionData(sourceLayerId: a, targetLayerId: b),
      );
      await notifier.saveConnection(
        LayerConnectionData(sourceLayerId: b, targetLayerId: c),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await notifier.deleteConnection(a, b);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final connections = await container.read(connectionsProvider.future);
      expect(connections, hasLength(1));
      expect(connections.first.sourceLayerId, b);
      expect(connections.first.targetLayerId, c);
    });

    test('stream error transitions state to AsyncError', () async {
      final controller = StreamController<List<LayerConnection>>();
      final errDb = _ErrorInjectDb(controller);
      final errContainer = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(errDb)],
      );

      await errContainer.read(connectionsProvider.future);
      controller.addError(StateError('db broken'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = errContainer.read(connectionsProvider);
      expect(state.hasError, isTrue);

      await controller.close();
      errContainer.dispose();
      await errDb.close();
    });
  });
}
