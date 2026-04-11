import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/repositories/app_repository.dart';
import 'package:gyeol/engine/layer_registry.dart';
import 'package:gyeol/engine/message_bus.dart';
import 'package:gyeol/engine/queue/task_queue.dart';
import 'package:gyeol/engine/scheduler.dart';

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

final repositoryProvider = Provider<AppRepository>((ref) {
  return AppRepository(ref.watch(databaseProvider));
});

final schedulerProvider = Provider<Scheduler>((ref) {
  final repo = ref.watch(repositoryProvider);
  final queue = TaskQueue();
  final registry = LayerRegistry();
  final bus = MessageBus();
  return Scheduler(
    queue: queue,
    layerRegistry: registry,
    messageBus: bus,
    repo: repo,
  );
});
