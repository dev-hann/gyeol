import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/engine/queue/task_queue.dart';

AppTask _makeTask({
  required String id,
  String taskType = 'test',
  TaskPriority priority = TaskPriority.medium,
  int createdAt = 1000,
}) {
  return AppTask(
    id: id,
    taskType: taskType,
    payload: <String, dynamic>{},
    priority: priority,
    status: TaskStatus.pending,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

void main() {
  group('TaskQueue', () {
    late TaskQueue queue;

    setUp(() {
      queue = TaskQueue();
    });

    test('empty queue — pop returns null', () {
      expect(queue.pop(), isNull);
    });

    test('empty queue — peek returns null', () {
      expect(queue.peek(), isNull);
    });

    test('empty queue — isEmpty is true and length is 0', () {
      expect(queue.isEmpty, isTrue);
      expect(queue.length, equals(0));
    });

    test('push then pop returns the task', () {
      final task = _makeTask(id: 'a');
      queue.push(task);
      final result = queue.pop();
      expect(result, isNotNull);
      expect(result!.id, equals('a'));
      expect(queue.isEmpty, isTrue);
    });

    test('higher priority tasks are popped first', () {
      queue
        ..push(_makeTask(id: 'low', priority: TaskPriority.low))
        ..push(_makeTask(id: 'high', priority: TaskPriority.high))
        ..push(_makeTask(id: 'med'));

      expect(queue.pop()!.id, equals('high'));
      expect(queue.pop()!.id, equals('med'));
      expect(queue.pop()!.id, equals('low'));
    });

    test('same priority — earlier createdAt popped first (FIFO)', () {
      queue
        ..push(_makeTask(id: 'first', createdAt: 100))
        ..push(_makeTask(id: 'second', createdAt: 200))
        ..push(_makeTask(id: 'third', createdAt: 300));

      expect(queue.pop()!.id, equals('first'));
      expect(queue.pop()!.id, equals('second'));
      expect(queue.pop()!.id, equals('third'));
    });

    test('peek returns highest priority without removing', () {
      queue
        ..push(_makeTask(id: 'low', priority: TaskPriority.low))
        ..push(_makeTask(id: 'high', priority: TaskPriority.high));

      expect(queue.peek()!.id, equals('high'));
      expect(queue.length, equals(2));
      expect(queue.peek()!.id, equals('high'));
    });

    test('length tracks queue size', () {
      expect(queue.length, equals(0));
      queue.push(_makeTask(id: 'a'));
      expect(queue.length, equals(1));
      queue.push(_makeTask(id: 'b'));
      expect(queue.length, equals(2));
      queue.pop();
      expect(queue.length, equals(1));
    });

    test('drainAll returns all tasks and clears queue', () {
      queue
        ..push(_makeTask(id: 'a', priority: TaskPriority.high))
        ..push(_makeTask(id: 'b', priority: TaskPriority.low));

      final drained = queue.drainAll();
      expect(drained.length, equals(2));
      expect(drained.any((t) => t.id == 'a'), isTrue);
      expect(drained.any((t) => t.id == 'b'), isTrue);
      expect(queue.isEmpty, isTrue);
      expect(queue.drainAll(), isEmpty);
    });

    test('pop on drained queue returns null', () {
      queue
        ..push(_makeTask(id: 'a'))
        ..drainAll();
      expect(queue.pop(), isNull);
    });

    test('mixed priorities and timestamps order correctly', () {
      queue
        ..push(
          _makeTask(id: 'low_old', priority: TaskPriority.low, createdAt: 100),
        )
        ..push(
          _makeTask(
            id: 'high_new',
            priority: TaskPriority.high,
            createdAt: 300,
          ),
        )
        ..push(_makeTask(id: 'med_mid', createdAt: 200))
        ..push(
          _makeTask(id: 'high_old', priority: TaskPriority.high, createdAt: 50),
        );

      expect(queue.pop()!.id, equals('high_old'));
      expect(queue.pop()!.id, equals('high_new'));
      expect(queue.pop()!.id, equals('med_mid'));
      expect(queue.pop()!.id, equals('low_old'));
    });

    test('maintains sorted order after many interleaved pushes', () {
      for (var i = 0; i < 50; i++) {
        queue.push(
          _makeTask(
            id: 'task-$i',
            priority: TaskPriority.values[i % 3],
            createdAt: i * 100,
          ),
        );
      }

      TaskPriority? prevPriority;
      int? prevCreatedAt;
      while (!queue.isEmpty) {
        final task = queue.pop()!;
        if (prevPriority != null) {
          expect(
            task.priority.index <= prevPriority.index,
            isTrue,
            reason:
                'Tasks should be ordered by priority desc (high first): '
                '${task.priority} came after $prevPriority',
          );
          if (task.priority == prevPriority && prevCreatedAt != null) {
            expect(
              task.createdAt >= prevCreatedAt,
              isTrue,
              reason: 'Same priority tasks should be FIFO',
            );
          }
        }
        prevPriority = task.priority;
        prevCreatedAt = task.createdAt;
      }
    });
  });
}
