import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/providers/core_providers.dart';
import 'package:gyeol/data/providers/logs_provider.dart';
import 'package:gyeol/data/providers/tasks_provider.dart';

final queueSizeProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(repositoryProvider);
  return repo.tasks.getQueueSize();
});

final runSchedulerProvider = FutureProvider.family<List<WorkerResult>, void>((
  ref,
  _,
) async {
  final scheduler = ref.read(schedulerProvider);
  final results = await scheduler.runOnce();
  ref
    ..invalidate(tasksProvider)
    ..invalidate(queueSizeProvider)
    ..invalidate(logsProvider);
  return results;
});
