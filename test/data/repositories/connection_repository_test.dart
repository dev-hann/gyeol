import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/models/layer_models.dart';
import 'package:gyeol/data/repositories/app_repository.dart';

void main() {
  Future<int> _createThread(AppDatabase database) async {
    await database.saveThread(
      ThreadsCompanion.insert(name: 'default', path: '/tmp'),
    );
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

  Future<int> insertLayer(String name) async {
    final layer = LayerDefinition(
      id: 0,
      threadId: _tid,
      name: '',
      inputTypes: [],
      outputTypes: [],
    );
    await repo.layers.saveLayer(layer.copyWith(name: name));
    final layers = await repo.layers.listLayers();
    return layers.firstWhere((l) => l.name == name).id;
  }

  group('listConnections', () {
    test('returns empty when no connections exist', () async {
      final connections = await repo.connections.listConnections();
      expect(connections, isEmpty);
    });
  });

  group('saveConnection + listConnections', () {
    test('round-trips a single connection', () async {
      final srcId = await insertLayer('source');
      final dstId = await insertLayer('target');

      await repo.connections.saveConnection(
        LayerConnectionData(sourceLayerId: srcId, targetLayerId: dstId),
      );

      final connections = await repo.connections.listConnections();
      expect(connections, hasLength(1));
      expect(connections.first.sourceLayerId, srcId);
      expect(connections.first.targetLayerId, dstId);
    });

    test('stores multiple connections', () async {
      final a = await insertLayer('a');
      final b = await insertLayer('b');
      final c = await insertLayer('c');

      await repo.connections.saveConnection(
        LayerConnectionData(sourceLayerId: a, targetLayerId: b),
      );
      await repo.connections.saveConnection(
        LayerConnectionData(sourceLayerId: b, targetLayerId: c),
      );

      final connections = await repo.connections.listConnections();
      expect(connections, hasLength(2));
    });

    test('upserts connection with same source and target', () async {
      final srcId = await insertLayer('source');
      final dstId = await insertLayer('target');

      await repo.connections.saveConnection(
        LayerConnectionData(sourceLayerId: srcId, targetLayerId: dstId),
      );
      await repo.connections.saveConnection(
        LayerConnectionData(sourceLayerId: srcId, targetLayerId: dstId),
      );

      final connections = await repo.connections.listConnections();
      expect(connections, hasLength(1));
    });
  });

  group('deleteConnection', () {
    test('removes specific connection', () async {
      final a = await insertLayer('a');
      final b = await insertLayer('b');
      final c = await insertLayer('c');

      await repo.connections.saveConnection(
        LayerConnectionData(sourceLayerId: a, targetLayerId: b),
      );
      await repo.connections.saveConnection(
        LayerConnectionData(sourceLayerId: b, targetLayerId: c),
      );

      await repo.connections.deleteConnection(a, b);

      final connections = await repo.connections.listConnections();
      expect(connections, hasLength(1));
      expect(connections.first.sourceLayerId, b);
      expect(connections.first.targetLayerId, c);
    });

    test('is no-op for non-existent connection', () async {
      final a = await insertLayer('a');
      final b = await insertLayer('b');

      await repo.connections.saveConnection(
        LayerConnectionData(sourceLayerId: a, targetLayerId: b),
      );

      await repo.connections.deleteConnection(999, 888);

      final connections = await repo.connections.listConnections();
      expect(connections, hasLength(1));
    });
  });

  group('deleteConnectionsByLayerId', () {
    test('removes all connections for a layer as source', () async {
      final a = await insertLayer('a');
      final b = await insertLayer('b');
      final c = await insertLayer('c');

      await repo.connections.saveConnection(
        LayerConnectionData(sourceLayerId: a, targetLayerId: b),
      );
      await repo.connections.saveConnection(
        LayerConnectionData(sourceLayerId: a, targetLayerId: c),
      );
      await repo.connections.saveConnection(
        LayerConnectionData(sourceLayerId: b, targetLayerId: c),
      );

      await repo.connections.deleteConnectionsByLayerId(a);

      final connections = await repo.connections.listConnections();
      expect(connections, hasLength(1));
      expect(connections.first.sourceLayerId, b);
    });

    test('removes all connections for a layer as target', () async {
      final a = await insertLayer('a');
      final b = await insertLayer('b');
      final c = await insertLayer('c');

      await repo.connections.saveConnection(
        LayerConnectionData(sourceLayerId: a, targetLayerId: c),
      );
      await repo.connections.saveConnection(
        LayerConnectionData(sourceLayerId: b, targetLayerId: c),
      );
      await repo.connections.saveConnection(
        LayerConnectionData(sourceLayerId: a, targetLayerId: b),
      );

      await repo.connections.deleteConnectionsByLayerId(c);

      final connections = await repo.connections.listConnections();
      expect(connections, hasLength(1));
      expect(connections.first.sourceLayerId, a);
      expect(connections.first.targetLayerId, b);
    });

    test('is no-op for layer with no connections', () async {
      final a = await insertLayer('a');
      final b = await insertLayer('b');

      await repo.connections.saveConnection(
        LayerConnectionData(sourceLayerId: a, targetLayerId: b),
      );

      final orphan = await insertLayer('orphan');
      await repo.connections.deleteConnectionsByLayerId(orphan);

      final connections = await repo.connections.listConnections();
      expect(connections, hasLength(1));
    });
  });

  group('watchConnections', () {
    test('emits update when connection is saved', () async {
      final stream = repo.connections.watchConnections();

      final firstEmission = await stream.first;
      expect(firstEmission, isEmpty);

      final a = await insertLayer('a');
      final b = await insertLayer('b');
      await repo.connections.saveConnection(
        LayerConnectionData(sourceLayerId: a, targetLayerId: b),
      );

      final secondEmission = await stream.first;
      expect(secondEmission, hasLength(1));
      expect(secondEmission.first.sourceLayerId, a);
      expect(secondEmission.first.targetLayerId, b);
    });
  });
}
