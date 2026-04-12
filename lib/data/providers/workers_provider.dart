import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/providers/core_providers.dart';

final workersProvider =
    AsyncNotifierProvider<WorkersNotifier, List<WorkerDefinition>>(
      WorkersNotifier.new,
    );

class WorkersNotifier extends AsyncNotifier<List<WorkerDefinition>> {
  StreamSubscription<List<WorkerDefinition>>? _sub;

  @override
  Future<List<WorkerDefinition>> build() async {
    final repo = ref.watch(repositoryProvider);
    await _sub?.cancel();
    _sub = repo.workers.watchWorkers().listen(
      (data) => state = AsyncData(data),
      onError: (Object e, StackTrace st) {
        state = AsyncError(e, st);
      },
    );
    ref.onDispose(() => _sub?.cancel());
    return repo.workers.listWorkers();
  }

  Future<void> saveWorker(WorkerDefinition worker) async {
    final repo = ref.read(repositoryProvider);
    await repo.workers.saveWorker(worker);
  }

  Future<void> deleteWorker(int id) async {
    final repo = ref.read(repositoryProvider);
    await repo.workers.deleteWorker(id);
  }
}
