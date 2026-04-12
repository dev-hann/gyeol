import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/providers/core_providers.dart';

final logsProvider = AsyncNotifierProvider<LogsNotifier, List<ExecutionLog>>(
  LogsNotifier.new,
);

class LogsNotifier extends AsyncNotifier<List<ExecutionLog>> {
  StreamSubscription<List<ExecutionLog>>? _sub;

  @override
  Future<List<ExecutionLog>> build() async {
    final repo = ref.watch(repositoryProvider);
    await _sub?.cancel();
    _sub = repo.logs.watchExecutionLogs().listen(
      (data) => state = AsyncData(data),
      onError: (Object e, StackTrace st) {
        state = AsyncError(e, st);
      },
    );
    ref.onDispose(() => _sub?.cancel());
    return repo.logs.listExecutionLogs();
  }
}
