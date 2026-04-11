import 'package:gyeol/data/models/app_models.dart';

class LayerRegistry {
  final List<LayerDefinition> _layers = [];

  void register(LayerDefinition layer) {
    _layers
      ..removeWhere((l) => l.name == layer.name)
      ..add(layer)
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  void remove(String name) {
    _layers.removeWhere((l) => l.name == name);
  }

  void setAll(List<LayerDefinition> layers) {
    _layers
      ..clear()
      ..addAll(layers)
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  List<LayerDefinition> findByInputType(String taskType) {
    return _layers
        .where((l) => l.enabled && l.inputTypes.contains(taskType))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }
}
