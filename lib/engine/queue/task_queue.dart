import 'package:gyeol/data/models/app_models.dart';

class _PrioritizedTask implements Comparable<_PrioritizedTask> {
  _PrioritizedTask(this.task)
    : priority = task.priority.index,
      createdAt = task.createdAt;
  final int priority;
  final int createdAt;
  final AppTask task;

  @override
  int compareTo(_PrioritizedTask other) {
    final cmp = priority.compareTo(other.priority);
    if (cmp != 0) return cmp;
    return other.createdAt.compareTo(createdAt);
  }
}

class TaskQueue {
  final List<_PrioritizedTask> _heap = [];

  void push(AppTask task) {
    final entry = _PrioritizedTask(task);
    if (_heap.isEmpty) {
      _heap.add(entry);
      return;
    }
    var lo = 0;
    var hi = _heap.length;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (entry.compareTo(_heap[mid]) < 0) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }
    _heap.insert(lo, entry);
  }

  AppTask? pop() {
    if (_heap.isEmpty) return null;
    return _heap.removeLast().task;
  }

  AppTask? peek() {
    if (_heap.isEmpty) return null;
    return _heap.last.task;
  }

  int get length => _heap.length;

  bool get isEmpty => _heap.isEmpty;

  List<AppTask> drainAll() {
    final tasks = _heap.map((p) => p.task).toList();
    _heap.clear();
    return tasks;
  }
}
