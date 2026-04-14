import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/providers/app_providers.dart';
import 'package:gyeol/features/monitoring/pages/monitoring_page.dart';

List<LayerDefinition> fakeLayers() => [
  const LayerDefinition(
    id: 1,
    threadId: 1,
    name: 'Draft',
    inputTypes: ['text'],
    outputTypes: ['draft'],
  ),
];

List<AppTask> fakeTasks() => [
  const AppTask(
    id: 0,
    uuid: 't1',
    taskType: 'generate',
    payload: null,
    priority: TaskPriority.high,
    status: TaskStatus.running,
    layerId: 1,
    workerId: 1,
    depth: 1,
    createdAt: 1000,
    updatedAt: 1000,
  ),
  const AppTask(
    id: 0,
    uuid: 't2',
    taskType: 'review',
    payload: null,
    priority: TaskPriority.medium,
    status: TaskStatus.pending,
    layerId: 1,
    depth: 2,
    retryCount: 1,
    createdAt: 2000,
    updatedAt: 2000,
  ),
  const AppTask(
    id: 0,
    uuid: 't3',
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
    taskId: 1,
    workerId: 1,
    status: 'success',
    message: 'Generated draft',
    createdAt: DateTime(2026, 1, 1, 12).millisecondsSinceEpoch,
  ),
  ExecutionLog(
    id: 2,
    taskId: 2,
    status: 'error',
    message: 'Timeout',
    createdAt: DateTime(2026, 1, 1, 12, 1).millisecondsSinceEpoch,
  ),
];

List<ExecutionLog> fakeLogsWithBoth() => [
  ExecutionLog(
    id: 1,
    taskId: 1,
    workerId: 1,
    status: 'success',
    message: 'Generated draft',
    createdAt: DateTime(2026, 1, 1, 12).millisecondsSinceEpoch,
  ),
  ExecutionLog(
    id: 2,
    taskId: 2,
    status: 'error',
    message: 'Timeout',
    createdAt: DateTime(2026, 1, 1, 12, 1).millisecondsSinceEpoch,
  ),
  ExecutionLog(
    id: 3,
    taskId: 3,
    workerId: 2,
    status: 'success',
    message: 'Reviewed content',
    createdAt: DateTime(2026, 1, 1, 12, 2).millisecondsSinceEpoch,
  ),
];

void main() {
  Future<void> pumpMonitoringPage(
    WidgetTester tester, {
    List<AppTask>? tasks,
    List<ExecutionLog>? logs,
    List<LayerDefinition>? layers,
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
          layersProvider.overrideWith(
            () => _FakeLayersNotifier(layers ?? fakeLayers()),
          ),
          workersProvider.overrideWith(
            () => _FakeWorkersNotifier(fakeWorkers()),
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
      expect(find.textContaining('Draft / writer-1'), findsAtLeast(1));
    });

    testWidgets('shows No active tasks when all done', (tester) async {
      await pumpMonitoringPage(
        tester,
        tasks: [
          const AppTask(
            id: 0,
            uuid: 't4',
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
      expect(find.text('writer-1'), findsAtLeast(1));
      expect(find.text('System'), findsOneWidget);
    });

    testWidgets('shows No logs yet when empty', (tester) async {
      await pumpMonitoringPage(tester, logs: []);
      expect(find.text('No logs yet'), findsOneWidget);
    });

    testWidgets('shows CircularProgressIndicator for running tasks', (
      tester,
    ) async {
      await pumpMonitoringPage(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows schedule icon for pending tasks', (tester) async {
      await pumpMonitoringPage(tester);
      expect(find.byIcon(Icons.schedule), findsOneWidget);
    });

    testWidgets('shows task depth and retry count in detail line', (
      tester,
    ) async {
      await pumpMonitoringPage(tester);
      expect(find.textContaining('Depth: 1'), findsOneWidget);
      expect(find.textContaining('Depth: 2'), findsOneWidget);
      expect(find.textContaining('Retry: 0/3'), findsOneWidget);
      expect(find.textContaining('Retry: 1/3'), findsOneWidget);
    });

    testWidgets('shows unassigned worker label when workerName is null', (
      tester,
    ) async {
      await pumpMonitoringPage(tester);
      expect(find.textContaining('unassigned'), findsOneWidget);
    });

    testWidgets('shows error on tasks provider error', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tasksProvider.overrideWith(_ErrorTasksNotifier.new),
            logsProvider.overrideWith(() => _FakeLogsNotifier(fakeLogs())),
            layersProvider.overrideWith(
              () => _FakeLayersNotifier(fakeLayers()),
            ),
          ],
          child: const MaterialApp(home: MonitoringPage()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Error:'), findsOneWidget);
    });
  });

  group('MonitoringPage filter tabs', () {
    testWidgets('shows All filter tab', (tester) async {
      await pumpMonitoringPage(tester);
      expect(find.widgetWithText(ChoiceChip, 'All'), findsNWidgets(2));
    });

    testWidgets('shows Success filter tab', (tester) async {
      await pumpMonitoringPage(tester);
      expect(find.text('Success'), findsOneWidget);
    });

    testWidgets('shows Failed filter tab', (tester) async {
      await pumpMonitoringPage(tester);
      expect(find.text('Failed'), findsOneWidget);
    });

    testWidgets('shows all logs by default', (tester) async {
      await pumpMonitoringPage(tester, logs: fakeLogsWithBoth());
      expect(find.text('writer-1'), findsAtLeast(1));
      expect(find.text('reviewer-1'), findsOneWidget);
    });

    testWidgets('filters logs to success only when Success tab tapped', (
      tester,
    ) async {
      await pumpMonitoringPage(tester, logs: fakeLogsWithBoth());
      await tester.tap(find.text('Success'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('writer-1'), findsAtLeast(1));
      expect(find.text('reviewer-1'), findsOneWidget);
      expect(find.text('System'), findsNothing);
    });

    testWidgets('filters logs to failed only when Failed tab tapped', (
      tester,
    ) async {
      await pumpMonitoringPage(tester, logs: fakeLogsWithBoth());
      await tester.tap(find.text('Failed'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('System'), findsOneWidget);
      expect(find.text('writer-1'), findsNothing);
      expect(find.text('reviewer-1'), findsNothing);
    });

    testWidgets('restores all logs when All tab tapped after filtering', (
      tester,
    ) async {
      await pumpMonitoringPage(tester, logs: fakeLogsWithBoth());
      await tester.tap(find.text('Failed'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final allChips = find.widgetWithText(ChoiceChip, 'All');
      await tester.tap(allChips.last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('writer-1'), findsAtLeast(1));
      expect(find.text('reviewer-1'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
    });
  });

  group('MonitoringPage task detail expansion', () {
    testWidgets('expands task detail on tap', (tester) async {
      await pumpMonitoringPage(tester);
      await tester.tap(find.text('generate'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Task ID:'), findsAtLeast(1));
    });

    testWidgets('shows full task id in expanded detail', (tester) async {
      await pumpMonitoringPage(tester);
      await tester.tap(find.text('generate'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('t1'), findsAtLeast(1));
    });

    testWidgets('shows layer name in expanded detail', (tester) async {
      await pumpMonitoringPage(tester);
      await tester.tap(find.text('generate'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Draft'), findsAtLeast(1));
    });

    testWidgets('shows retry count in expanded detail', (tester) async {
      await pumpMonitoringPage(tester);
      await tester.tap(find.text('generate'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Retry'), findsAtLeast(1));
    });

    testWidgets('collapses task detail on second tap', (tester) async {
      await pumpMonitoringPage(tester);
      await tester.tap(find.text('generate'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Task ID:'), findsAtLeast(1));
      await tester.tap(find.text('generate'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Task ID:'), findsNothing);
    });
  });
}

class _FakeTasksNotifier extends TasksNotifier {
  _FakeTasksNotifier(this._tasks);
  final List<AppTask> _tasks;

  @override
  Future<List<AppTask>> build() async => _tasks;
}

class _FakeLogsNotifier extends LogsNotifier {
  _FakeLogsNotifier(this._logs);
  final List<ExecutionLog> _logs;

  @override
  Future<List<ExecutionLog>> build() async => _logs;
}

class _FakeLayersNotifier extends LayersNotifier {
  _FakeLayersNotifier(this._layers);
  final List<LayerDefinition> _layers;

  @override
  Future<List<LayerDefinition>> build() async => _layers;
}

class _ErrorTasksNotifier extends TasksNotifier {
  @override
  Future<List<AppTask>> build() async => throw Exception('db failed');
}

List<WorkerDefinition> fakeWorkers() => [
  const WorkerDefinition(
    id: 1,
    name: 'writer-1',
    layerId: 1,
    systemPrompt: 'p',
  ),
  const WorkerDefinition(
    id: 2,
    name: 'reviewer-1',
    layerId: 1,
    systemPrompt: 'p',
  ),
];

class _FakeWorkersNotifier extends WorkersNotifier {
  _FakeWorkersNotifier(this._workers);
  final List<WorkerDefinition> _workers;

  @override
  Future<List<WorkerDefinition>> build() async => _workers;
}
