import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/providers/core_providers.dart';

final threadsProvider =
    AsyncNotifierProvider<ThreadsNotifier, List<ThreadDefinition>>(
      ThreadsNotifier.new,
    );

class ThreadsNotifier extends AsyncNotifier<List<ThreadDefinition>> {
  StreamSubscription<List<ThreadDefinition>>? _sub;

  @override
  Future<List<ThreadDefinition>> build() async {
    final repo = ref.watch(repositoryProvider);
    await _sub?.cancel();
    _sub = repo.threads.watchThreads().listen(
      (data) => state = AsyncData(data),
    );
    ref.onDispose(() => _sub?.cancel());
    return repo.threads.listThreads();
  }

  Future<void> saveThread(ThreadDefinition thread) async {
    final repo = ref.read(repositoryProvider);
    await repo.threads.saveThread(thread);
  }

  Future<void> deleteThread(int id) async {
    final repo = ref.read(repositoryProvider);
    await repo.threads.deleteThread(id);
  }
}
