import 'package:gyeol/data/models/app_models.dart';

class MessageBus {
  final Map<String, List<void Function(AppTask)>> _subscribers = {};

  void publish(AppTask task, {void Function(Object error)? onError}) {
    final specific = _subscribers[task.taskType] ?? [];
    final wildcard = _subscribers['*'] ?? [];
    for (final handler in [...specific, ...wildcard]) {
      try {
        handler(task);
      } on Object catch (e) {
        onError?.call(e);
      }
    }
  }

  void subscribe(String taskType, void Function(AppTask) handler) {
    _subscribers.putIfAbsent(taskType, () => []).add(handler);
  }
}
