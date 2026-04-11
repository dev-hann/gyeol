import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/models/layer_models.dart';

class LayerRepository {
  LayerRepository(this._db);
  final AppDatabase _db;

  Future<void> saveLayer(LayerDefinition layer) {
    return _db.saveLayer(
      LayersCompanion(
        id: layer.id == 0 ? const Value.absent() : Value(layer.id),
        name: Value(layer.name),
        inputTypes: Value(jsonEncode(layer.inputTypes)),
        outputTypes: Value(jsonEncode(layer.outputTypes)),
        layerPrompt: Value(layer.layerPrompt),
        sortOrder: Value(layer.order),
        enabled: Value(layer.enabled),
      ),
    );
  }

  Future<List<LayerDefinition>> listLayers() async {
    final rows = await _db.listLayers();
    return rows
        .map(
          (r) => LayerDefinition(
            id: r.id,
            name: r.name,
            inputTypes: _decodeStringList(r.inputTypes),
            outputTypes: _decodeStringList(r.outputTypes),
            layerPrompt: r.layerPrompt,
            order: r.sortOrder,
            enabled: r.enabled,
          ),
        )
        .toList();
  }

  Stream<List<LayerDefinition>> watchLayers() {
    return _db.watchLayers().map(
      (rows) => rows
          .map(
            (r) => LayerDefinition(
              id: r.id,
              name: r.name,
              inputTypes: _decodeStringList(r.inputTypes),
              outputTypes: _decodeStringList(r.outputTypes),
              layerPrompt: r.layerPrompt,
              order: r.sortOrder,
              enabled: r.enabled,
            ),
          )
          .toList(),
    );
  }

  Future<void> deleteLayer(int id) => _db.deleteLayer(id);

  List<String> _decodeStringList(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! List) return [];
      return decoded.whereType<String>().toList();
    } on FormatException {
      return [];
    }
  }
}
