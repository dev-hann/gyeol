import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/providers/core_providers.dart';

final layersProvider =
    AsyncNotifierProvider<LayersNotifier, List<LayerDefinition>>(
      LayersNotifier.new,
    );

class LayersNotifier extends AsyncNotifier<List<LayerDefinition>> {
  StreamSubscription<List<LayerDefinition>>? _sub;

  @override
  Future<List<LayerDefinition>> build() async {
    final repo = ref.watch(repositoryProvider);
    await _sub?.cancel();
    _sub = repo.layers.watchLayers().listen((data) => state = AsyncData(data));
    ref.onDispose(() => _sub?.cancel());
    return repo.layers.listLayers();
  }

  Future<void> saveLayer(LayerDefinition layer) async {
    final repo = ref.read(repositoryProvider);
    await repo.layers.saveLayer(layer);
  }

  Future<void> deleteLayer(String name) async {
    final repo = ref.read(repositoryProvider);
    await repo.layers.deleteLayer(name);
  }
}
