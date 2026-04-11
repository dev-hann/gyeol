import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/models/task_models.dart';

void main() {
  group('TaskPriority', () {
    test('has exactly three values', () {
      expect(TaskPriority.values, hasLength(3));
    });

    test('values are low, medium, high', () {
      expect(
        TaskPriority.values,
        containsAll([TaskPriority.low, TaskPriority.medium, TaskPriority.high]),
      );
    });
  });

  group('TaskStatus', () {
    test('has exactly four values', () {
      expect(TaskStatus.values, hasLength(4));
    });

    test('values are pending, running, done, failed', () {
      expect(
        TaskStatus.values,
        containsAll([
          TaskStatus.pending,
          TaskStatus.running,
          TaskStatus.done,
          TaskStatus.failed,
        ]),
      );
    });
  });

  group('AppTask', () {
    test('constructor sets all fields', () {
      const task = AppTask(
        id: 'abc',
        taskType: 'summarize',
        payload: {'key': 'value'},
        priority: TaskPriority.high,
        status: TaskStatus.pending,
        createdAt: 1000,
        updatedAt: 1000,
        retryCount: 1,
        maxRetries: 5,
        depth: 2,
        parentTaskId: 'parent',
        layerId: 1,
        workerName: 'worker1',
      );

      expect(task.id, 'abc');
      expect(task.taskType, 'summarize');
      expect(task.payload, {'key': 'value'});
      expect(task.priority, TaskPriority.high);
      expect(task.status, TaskStatus.pending);
      expect(task.createdAt, 1000);
      expect(task.updatedAt, 1000);
      expect(task.retryCount, 1);
      expect(task.maxRetries, 5);
      expect(task.depth, 2);
      expect(task.parentTaskId, 'parent');
      expect(task.layerId, 1);
      expect(task.workerName, 'worker1');
    });

    test('constructor defaults optional fields', () {
      const task = AppTask(
        id: 'x',
        taskType: 't',
        payload: null,
        priority: TaskPriority.low,
        status: TaskStatus.done,
        createdAt: 0,
        updatedAt: 0,
      );

      expect(task.retryCount, 0);
      expect(task.maxRetries, 3);
      expect(task.depth, 0);
      expect(task.parentTaskId, isNull);
      expect(task.layerId, isNull);
      expect(task.workerName, isNull);
    });

    test('create factory generates unique IDs', () {
      final a = AppTask.create('type', null, TaskPriority.medium);
      final b = AppTask.create('type', null, TaskPriority.medium);

      expect(a.id, isNotEmpty);
      expect(b.id, isNotEmpty);
      expect(a.id, isNot(equals(b.id)));
    });

    test('create factory sets status to pending', () {
      final task = AppTask.create('analyze', {'data': 1}, TaskPriority.high);

      expect(task.status, TaskStatus.pending);
      expect(task.taskType, 'analyze');
      expect(task.payload, {'data': 1});
      expect(task.priority, TaskPriority.high);
    });

    test('create factory sets createdAt and updatedAt to same value', () {
      final task = AppTask.create('t', null, TaskPriority.low);

      expect(task.createdAt, greaterThan(0));
      expect(task.updatedAt, equals(task.createdAt));
    });

    test('equality is based on id only', () {
      const a = AppTask(
        id: 'same',
        taskType: 'a',
        payload: null,
        priority: TaskPriority.low,
        status: TaskStatus.pending,
        createdAt: 100,
        updatedAt: 100,
      );
      const b = AppTask(
        id: 'same',
        taskType: 'b',
        payload: {'x': 1},
        priority: TaskPriority.high,
        status: TaskStatus.done,
        createdAt: 200,
        updatedAt: 200,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different ids are not equal', () {
      const a = AppTask(
        id: 'a',
        taskType: 't',
        payload: null,
        priority: TaskPriority.low,
        status: TaskStatus.pending,
        createdAt: 0,
        updatedAt: 0,
      );
      const b = AppTask(
        id: 'b',
        taskType: 't',
        payload: null,
        priority: TaskPriority.low,
        status: TaskStatus.pending,
        createdAt: 0,
        updatedAt: 0,
      );

      expect(a, isNot(equals(b)));
    });

    test('is not equal to non-AppTask objects', () {
      const task = AppTask(
        id: 'x',
        taskType: 't',
        payload: null,
        priority: TaskPriority.low,
        status: TaskStatus.pending,
        createdAt: 0,
        updatedAt: 0,
      );

      expect(task, isNot(equals('x')));
      expect(task, isNot(equals(42)));
    });

    test('copyWith overrides specified fields', () {
      const original = AppTask(
        id: 'id1',
        taskType: 'type1',
        payload: null,
        priority: TaskPriority.low,
        status: TaskStatus.pending,
        createdAt: 100,
        updatedAt: 100,
      );

      final copied = original.copyWith(
        status: TaskStatus.running,
        layerId: 1,
        workerName: 'workerA',
        retryCount: 2,
        depth: 3,
        parentTaskId: 'parent1',
        updatedAt: 200,
      );

      expect(copied.id, 'id1');
      expect(copied.taskType, 'type1');
      expect(copied.payload, isNull);
      expect(copied.priority, TaskPriority.low);
      expect(copied.createdAt, 100);
      expect(copied.maxRetries, 3);
      expect(copied.status, TaskStatus.running);
      expect(copied.layerId, 1);
      expect(copied.workerName, 'workerA');
      expect(copied.retryCount, 2);
      expect(copied.depth, 3);
      expect(copied.parentTaskId, 'parent1');
      expect(copied.updatedAt, 200);
    });

    test('copyWith preserves fields when not specified', () {
      const original = AppTask(
        id: 'id1',
        taskType: 'type1',
        payload: {'k': 'v'},
        priority: TaskPriority.high,
        status: TaskStatus.running,
        createdAt: 100,
        updatedAt: 100,
        retryCount: 2,
        maxRetries: 5,
        depth: 1,
        parentTaskId: 'p',
        layerId: 1,
        workerName: 'W',
      );

      final copied = original.copyWith();

      expect(copied.id, original.id);
      expect(copied.taskType, original.taskType);
      expect(copied.payload, original.payload);
      expect(copied.priority, original.priority);
      expect(copied.status, original.status);
      expect(copied.createdAt, original.createdAt);
      expect(copied.updatedAt, original.updatedAt);
      expect(copied.retryCount, original.retryCount);
      expect(copied.maxRetries, original.maxRetries);
      expect(copied.depth, original.depth);
      expect(copied.parentTaskId, original.parentTaskId);
      expect(copied.layerId, original.layerId);
      expect(copied.workerName, original.workerName);
    });

    test('priorityLabel returns correct labels', () {
      expect(
        const AppTask(
          id: '',
          taskType: '',
          payload: null,
          priority: TaskPriority.high,
          status: TaskStatus.pending,
          createdAt: 0,
          updatedAt: 0,
        ).priorityLabel,
        'High',
      );
      expect(
        const AppTask(
          id: '',
          taskType: '',
          payload: null,
          priority: TaskPriority.medium,
          status: TaskStatus.pending,
          createdAt: 0,
          updatedAt: 0,
        ).priorityLabel,
        'Medium',
      );
      expect(
        const AppTask(
          id: '',
          taskType: '',
          payload: null,
          priority: TaskPriority.low,
          status: TaskStatus.pending,
          createdAt: 0,
          updatedAt: 0,
        ).priorityLabel,
        'Low',
      );
    });

    test('statusLabel returns correct labels', () {
      expect(
        const AppTask(
          id: '',
          taskType: '',
          payload: null,
          priority: TaskPriority.low,
          status: TaskStatus.pending,
          createdAt: 0,
          updatedAt: 0,
        ).statusLabel,
        'Pending',
      );
      expect(
        const AppTask(
          id: '',
          taskType: '',
          payload: null,
          priority: TaskPriority.low,
          status: TaskStatus.running,
          createdAt: 0,
          updatedAt: 0,
        ).statusLabel,
        'Running',
      );
      expect(
        const AppTask(
          id: '',
          taskType: '',
          payload: null,
          priority: TaskPriority.low,
          status: TaskStatus.done,
          createdAt: 0,
          updatedAt: 0,
        ).statusLabel,
        'Done',
      );
      expect(
        const AppTask(
          id: '',
          taskType: '',
          payload: null,
          priority: TaskPriority.low,
          status: TaskStatus.failed,
          createdAt: 0,
          updatedAt: 0,
        ).statusLabel,
        'Failed',
      );
    });
  });

  group('WorkerResult', () {
    test('successful result with defaults', () {
      const result = WorkerResult(success: true);

      expect(result.success, true);
      expect(result.outputTasks, isEmpty);
      expect(result.error, isNull);
      expect(result.metadata, isNull);
    });

    test('failed result with error and metadata', () {
      final result = WorkerResult(
        success: false,
        error: 'timeout',
        metadata: {'retry': 3},
        outputTasks: [AppTask.create('sub', null, TaskPriority.low)],
      );

      expect(result.success, false);
      expect(result.error, 'timeout');
      expect(result.metadata, {'retry': 3});
      expect(result.outputTasks, hasLength(1));
    });
  });

  group('EvaluationResult', () {
    test('passed result', () {
      const result = EvaluationResult(
        passed: true,
        score: 0.95,
        reasons: ['good quality'],
      );

      expect(result.passed, true);
      expect(result.score, closeTo(0.95, 0.001));
      expect(result.reasons, ['good quality']);
    });

    test('failed result with multiple reasons', () {
      const result = EvaluationResult(
        passed: false,
        score: 0.3,
        reasons: ['low score', 'missing sections'],
      );

      expect(result.passed, false);
      expect(result.score, 0.3);
      expect(result.reasons, hasLength(2));
    });
  });
}
