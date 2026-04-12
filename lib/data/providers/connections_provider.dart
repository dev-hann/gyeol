import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gyeol/data/providers/core_providers.dart';
import 'package:gyeol/data/repositories/connection_repository.dart';

final connectionsProvider =
    AsyncNotifierProvider<ConnectionsNotifier, List<LayerConnectionData>>(
      ConnectionsNotifier.new,
    );

class ConnectionsNotifier extends AsyncNotifier<List<LayerConnectionData>> {
  StreamSubscription<List<LayerConnectionData>>? _sub;

  @override
  Future<List<LayerConnectionData>> build() async {
    final repo = ref.watch(repositoryProvider);
    await _sub?.cancel();
    _sub = repo.connections.watchConnections().listen(
      (data) => state = AsyncData(data),
      onError: (Object e, StackTrace st) {
        state = AsyncError(e, st);
      },
    );
    ref.onDispose(() => _sub?.cancel());
    return repo.connections.listConnections();
  }

  Future<void> saveConnection(LayerConnectionData c) async {
    await ref.read(repositoryProvider).connections.saveConnection(c);
  }

  Future<void> deleteConnection(int src, int dst) async {
    await ref.read(repositoryProvider).connections.deleteConnection(src, dst);
  }
}
