import 'package:gyeol/data/database/database.dart';

class LayerConnectionData {
  const LayerConnectionData({
    required this.sourceLayerId,
    required this.targetLayerId,
  });
  final int sourceLayerId;
  final int targetLayerId;
}

class ConnectionRepository {
  ConnectionRepository(this._db);
  final AppDatabase _db;

  Future<void> saveConnection(LayerConnectionData c) => _db.saveConnection(
    LayerConnectionsCompanion.insert(
      sourceLayerId: c.sourceLayerId,
      targetLayerId: c.targetLayerId,
    ),
  );

  Future<void> deleteConnection(int src, int dst) =>
      _db.deleteConnection(src, dst);

  Future<void> deleteConnectionsByLayerId(int id) =>
      _db.deleteConnectionsByLayerId(id);

  Future<List<LayerConnectionData>> listConnections() async =>
      (await _db.listConnections())
          .map(
            (r) => LayerConnectionData(
              sourceLayerId: r.sourceLayerId,
              targetLayerId: r.targetLayerId,
            ),
          )
          .toList();

  Stream<List<LayerConnectionData>> watchConnections() =>
      _db.watchConnections().map(
        (rows) => rows
            .map(
              (r) => LayerConnectionData(
                sourceLayerId: r.sourceLayerId,
                targetLayerId: r.targetLayerId,
              ),
            )
            .toList(),
      );
}
