import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/providers/app_providers.dart';
import 'package:gyeol/features/monitoring/pages/monitoring_page.dart';

import 'package:gyeol/data/database/database.dart';

List<AppTask> fakeTasks() => [
  AppTask(
    id: 't1',
    taskType: 'generate',
    payload: null,
    priority: TaskPriority.high,
    status: TaskStatus.running,
    layerName: 'Draft',
    workerName: 'writer-1',
    depth: 1,
    retryCount: 0,
    maxRetries: 3,
    createdAt: 1000,
    updatedAt: 1000,
  ),
  AppTask(
    id: 't2',
    taskType: 'review',
    payload: null,
    priority: TaskPriority.medium,
    status: TaskStatus.pending,
    layerName: 'Review',
    workerName: null,
    depth: 2,
    retryCount: 1,
    maxRetries: 3,
    createdAt: 2000,
    updatedAt: 2000,
  ),
  AppTask(
    id: 't3',
    taskType: 'done-task',
    payload: null,
    priority: TaskPriority.low,
    status: TaskStatus.done,
    createdAt: 3000,
    updatedAt: 3000,
  ),
];

List<ExecutionLog> fakeLogs() => [
  ExecutionLog(
    id: 1,
    taskId: 't1',
    workerName: 'writer-1',
    status: 'success',
    message: 'Generated draft',
    createdAt: DateTime(2026, 1, 1, 12, 0, 0).millisecondsSinceEpoch,
  ),
  ExecutionLog(
    id: 2,
    taskId: 't2',
    workerName: null,
    status: 'error',
    message: 'Timeout',
    createdAt: DateTime(2026, 1, 1, 12, 1, 0).millisecondsSinceEpoch,
  ),
];

void main() {
  Future<void> pumpMonitoringPage(
    WidgetTester tester, {
    List<AppTask>? tasks,
    List<ExecutionLog>? logs,
  }) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tasksProvider.overrideWith(
            () => _FakeTasksNotifier(tasks ?? fakeTasks()),
          ),
          logsProvider.overrideWith(
            () => _FakeLogsNotifier(logs ?? fakeLogs()),
          ),
        ],
        child: const MaterialApp(home: MonitoringPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  group('MonitoringPage', () {
    testWidgets('renders PageHeader with Real-time Monitoring title', (
      tester,
    ) async {
      await pumpMonitoringPage(tester);
      expect(find.text('Real-time Monitoring'), findsOneWidget);
    });

    testWidgets('renders description text', (tester) async {
      await pumpMonitoringPage(tester);
      expect(
        find.text('Live view of task execution and worker activity'),
        findsOneWidget,
      );
    });

    testWidgets('renders Active Tasks card header', (tester) async {
      await pumpMonitoringPage(tester);
      expect(find.text('Active Tasks'), findsOneWidget);
    });

    testWidgets('renders Execution Logs card header', (tester) async {
      await pumpMonitoringPage(tester);
      expect(find.text('Execution Logs'), findsOneWidget);
    });

    testWidgets('shows running count in Active Tasks', (tester) async {
      await pumpMonitoringPage(tester);
      expect(find.text('1 running'), findsOneWidget);
    });

    testWidgets('shows active task type names', (tester) async {
      await pumpMonitoringPage(tester);
      expect(find.text('generate'), findsOneWidget);
      expect(find.text('review'), findsOneWidget);
    });

    testWidgets('shows task detail info with layer and worker', (tester) async {
      await pumpMonitoringPage(tester);
      expect(find.textContaining('Draft / writer-1'), findsOneWidget);
    });

    testWidgets('shows No active tasks when all done', (tester) async {
      await pumpMonitoringPage(
        tester,
        tasks: [
          AppTask(
            id: 't4',
            taskType: 'done-task',
            payload: null,
            priority: TaskPriority.low,
            status: TaskStatus.done,
            createdAt: 4000,
            updatedAt: 4000,
          ),
        ],
      );
      expect(find.text('No active tasks'), findsOneWidget);
    });

    testWidgets('shows execution log worker names', (tester) async {
      await pumpMonitoringPage(tester);
      expect(find.text('writer-1'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
    });

    testWidgets('shows No logs yet when empty', (tester) async {
      await pumpMonitoringPage(tester, logs: []);
      expect(find.text('No logs yet'), findsOneWidget);
    });

    testWidgets('shows error on tasks provider error', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tasksProvider.overrideWith(() => _ErrorTasksNotifier()),
            logsProvider.overrideWith(() => _FakeLogsNotifier(fakeLogs())),
          ],
          child: const MaterialApp(home: MonitoringPage()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Error:'), findsOneWidget);
    });
  });
}

class _FakeTasksNotifier extends TasksNotifier {
  final List<AppTask> _tasks;
  _FakeTasksNotifier(this._tasks);

  @override
  Future<List<AppTask>> build() async => _tasks;
}

class _FakeLogsNotifier extends LogsNotifier {
  final List<ExecutionLog> _logs;
  _FakeLogsNotifier(this._logs);

  @override
  Future<List<ExecutionLog>> build() async => _logs;
}

class _ErrorTasksNotifier extends TasksNotifier {
  @override
  Future<List<AppTask>> build() async => throw Exception('db failed');
}
