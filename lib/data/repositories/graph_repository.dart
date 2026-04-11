import 'dart:convert';
import 'dart:ui';

import 'package:gyeol/data/database/database.dart';

class GraphRepository {
  GraphRepository(this._db);
  final AppDatabase _db;

  Future<Map<String, Offset>> loadNodePositions() async {
    final json = await _db.getUiState('graph_node_positions');
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
    return _db.saveUiState('graph_node_positions', encoded);
  }

  Future<(double, double, double)> loadViewport() async {
    final json = await _db.getUiState('graph_viewport');
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
    return _db.saveUiState(
      'graph_viewport',
      jsonEncode({'x': x, 'y': y, 'zoom': zoom}),
    );
  }
}
