import 'dart:convert';
import 'dart:ui';

import 'package:gyeol/data/database/database.dart';

class GraphRepository {
  GraphRepository(this._db);
  final AppDatabase _db;

  Future<Map<String, Offset>> loadNodePositions() async {
    final json = await _db.getJsonValue('graph_node_positions');
    if (json == null) return {};
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, dynamic>) return {};
      final result = <String, Offset>{};
      for (final entry in decoded.entries) {
        final v = entry.value;
        if (v is! List || v.length < 2) continue;
        if (v[0] is num && v[1] is num) {
          result[entry.key] = Offset(
            (v[0] as num).toDouble(),
            (v[1] as num).toDouble(),
          );
        }
      }
      return result;
    } on FormatException {
      return {};
    }
  }

  Future<void> saveNodePositions(Map<String, Offset> positions) {
    final encoded = jsonEncode(
      positions.map((k, v) => MapEntry(k, [v.dx, v.dy])),
    );
    return _db.saveJsonValue('graph_node_positions', encoded);
  }

  Future<Set<(String, String)>> loadRemovedConnections() =>
      _loadStringPairSet('graph_removed_connections');

  Future<void> saveRemovedConnections(Set<(String, String)> connections) =>
      _saveStringPairSet('graph_removed_connections', connections);

  Future<(double, double, double)> loadViewport() async {
    final json = await _db.getJsonValue('graph_viewport');
    if (json == null) return (0.0, 0.0, 1.0);
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, dynamic>) return (0.0, 0.0, 1.0);
      final rawX = decoded['x'];
      final rawY = decoded['y'];
      final rawZoom = decoded['zoom'];
      final x = rawX is num ? rawX.toDouble() : 0.0;
      final y = rawY is num ? rawY.toDouble() : 0.0;
      final zoom = rawZoom is num ? rawZoom.toDouble() : 1.0;
      return (x, y, zoom);
    } on FormatException {
      return (0.0, 0.0, 1.0);
    }
  }

  Future<void> saveViewport(double x, double y, double zoom) {
    return _db.saveJsonValue(
      'graph_viewport',
      jsonEncode({'x': x, 'y': y, 'zoom': zoom}),
    );
  }

  Future<Set<(String, String)>> _loadStringPairSet(String key) async {
    final json = await _db.getJsonValue(key);
    if (json == null) return {};
    try {
      final decoded = jsonDecode(json);
      if (decoded is! List) return {};
      final result = <(String, String)>{};
      for (final e in decoded) {
        if (e is List && e.length >= 2 && e[0] is String && e[1] is String) {
          result.add((e[0] as String, e[1] as String));
        }
      }
      return result;
    } on FormatException {
      return {};
    }
  }

  Future<void> _saveStringPairSet(
    String key,
    Set<(String, String)> connections,
  ) {
    final encoded = jsonEncode(connections.map((c) => [c.$1, c.$2]).toList());
    return _db.saveJsonValue(key, encoded);
  }
}
