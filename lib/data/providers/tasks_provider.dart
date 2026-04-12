import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/providers/core_providers.dart';

final tasksProvider = AsyncNotifierProvider<TasksNotifier, List<AppTask>>(
  TasksNotifier.new,
);

class TasksNotifier extends AsyncNotifier<List<AppTask>> {
  StreamSubscription<List<AppTask>>? _sub;

  @override
  Future<List<AppTask>> build() async {
    final repo = ref.watch(repositoryProvider);
    await _sub?.cancel();
    _sub = repo.tasks.watchTasks().listen(
      (data) => state = AsyncData(data),
      onError: (Object e, StackTrace st) {
        state = AsyncError(e, st);
      },
    );
    ref.onDispose(() => _sub?.cancel());
    return repo.tasks.listTasks();
  }

  Future<int> createTask(
    String type,
    Object? payload,
    TaskPriority priority,
  ) async {
    final repo = ref.read(repositoryProvider);
    final id = await repo.tasks.createTask(type, payload, priority);
    return id;
  }
}
