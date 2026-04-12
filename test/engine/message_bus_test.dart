// ignore_for_file: cascade_invocations
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/engine/message_bus.dart';

AppTask _makeTask({
  required String taskType,
  TaskStatus status = TaskStatus.pending,
}) {
  return AppTask(
    id: 0,
    uuid: 'test-id',
    taskType: taskType,
    payload: <String, dynamic>{},
    priority: TaskPriority.medium,
    status: status,
    createdAt: 1000,
    updatedAt: 1000,
  );
}

void main() {
  group('MessageBus', () {
    late MessageBus bus;

    setUp(() {
      bus = MessageBus();
    });

    test('publish with no subscribers — no error', () {
      bus.publish(_makeTask(taskType: 'analysis'));
    });

    test('subscribe and publish — handler receives task', () {
      final task = _makeTask(taskType: 'analysis');
      AppTask? received;
      bus.subscribe('analysis', (t) => received = t);
      bus.publish(task);
      expect(received, equals(task));
    });

    test('multiple subscribers on same type — all receive', () {
      var count = 0;
      bus.subscribe('analysis', (_) => count++);
      bus.subscribe('analysis', (_) => count++);
      bus.publish(_makeTask(taskType: 'analysis'));
      expect(count, equals(2));
    });

    test('wildcard subscriber receives all task types', () {
      var count = 0;
      bus.subscribe('*', (_) => count++);
      bus.publish(_makeTask(taskType: 'analysis'));
      bus.publish(_makeTask(taskType: 'generation'));
      bus.publish(_makeTask(taskType: 'evaluation'));
      expect(count, equals(3));
    });

    test('specific and wildcard subscribers both receive', () {
      var specificCount = 0;
      var wildcardCount = 0;
      bus.subscribe('analysis', (_) => specificCount++);
      bus.subscribe('*', (_) => wildcardCount++);
      bus.publish(_makeTask(taskType: 'analysis'));
      expect(specificCount, equals(1));
      expect(wildcardCount, equals(1));
    });

    test('subscriber for different type does not receive', () {
      AppTask? received;
      bus.subscribe('generation', (t) => received = t);
      bus.publish(_makeTask(taskType: 'analysis'));
      expect(received, isNull);
    });

    test('publish multiple tasks — each delivered once', () {
      final received = <String>[];
      bus.subscribe('analysis', (t) => received.add(t.uuid));
      bus.publish(_makeTask(taskType: 'analysis'));
      const secondTask = AppTask(
        id: 0,
        uuid: 'other-id',
        taskType: 'analysis',
        payload: null,
        priority: TaskPriority.high,
        status: TaskStatus.pending,
        createdAt: 2000,
        updatedAt: 2000,
      );
      bus.publish(secondTask);
      expect(received, equals(['test-id', 'other-id']));
    });

    test('task with different status delivered correctly', () {
      AppTask? received;
      bus.subscribe('analysis', (t) => received = t);
      bus.publish(_makeTask(taskType: 'analysis', status: TaskStatus.running));
      expect(received?.status, equals(TaskStatus.running));
    });
  });
}
