import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/providers/app_providers.dart';
import 'package:gyeol/features/dashboard/pages/dashboard_page.dart';

List<AppTask> fakeTasks() => [
  AppTask(
    id: 'aaaaaaaa-0000-0000-0000-000000000001',
    taskType: 'Generate',
    payload: null,
    priority: TaskPriority.high,
    status: TaskStatus.pending,
    createdAt: DateTime(2025, 1, 1, 12, 0, 0).millisecondsSinceEpoch,
    updatedAt: DateTime(2025, 1, 1, 12, 0, 0).millisecondsSinceEpoch,
  ),
  AppTask(
    id: 'bbbbbbbb-0000-0000-0000-000000000002',
    taskType: 'Evaluate',
    payload: null,
    priority: TaskPriority.medium,
    status: TaskStatus.running,
    layerName: 'Draft',
    workerName: 'writer-1',
    createdAt: DateTime(2025, 1, 1, 12, 1, 0).millisecondsSinceEpoch,
    updatedAt: DateTime(2025, 1, 1, 12, 1, 0).millisecondsSinceEpoch,
  ),
  AppTask(
    id: 'cccccccc-0000-0000-0000-000000000003',
    taskType: 'Research',
    payload: null,
    priority: TaskPriority.low,
    status: TaskStatus.done,
    createdAt: DateTime(2025, 1, 1, 12, 2, 0).millisecondsSinceEpoch,
    updatedAt: DateTime(2025, 1, 1, 12, 2, 0).millisecondsSinceEpoch,
  ),
  AppTask(
    id: 'dddddddd-0000-0000-0000-000000000004',
    taskType: 'Translate',
    payload: null,
    priority: TaskPriority.high,
    status: TaskStatus.failed,
    createdAt: DateTime(2025, 1, 1, 12, 3, 0).millisecondsSinceEpoch,
    updatedAt: DateTime(2025, 1, 1, 12, 3, 0).millisecondsSinceEpoch,
  ),
];

void main() {
  Future<void> pumpDashboard(
    WidgetTester tester, {
    List<AppTask>? tasks,
    int queueSize = 2,
  }) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tasksProvider.overrideWith(
            () => _FakeTasksNotifier(tasks ?? fakeTasks()),
          ),
          queueSizeProvider.overrideWith((ref) async => queueSize),
        ],
        child: const MaterialApp(home: DashboardPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('DashboardPage', () {
    testWidgets('renders PageHeader with Dashboard title', (tester) async {
      await pumpDashboard(tester);
      expect(find.text('Dashboard'), findsOneWidget);
    });

    testWidgets('renders PageHeader description', (tester) async {
      await pumpDashboard(tester);
      expect(find.text('Overview of your AI worker system'), findsOneWidget);
    });

    testWidgets('shows stat cards with correct labels', (tester) async {
      await pumpDashboard(tester);
      expect(find.text('QUEUE'), findsOneWidget);
      expect(find.text('PENDING'), findsOneWidget);
      expect(find.text('RUNNING'), findsOneWidget);
      expect(find.text('COMPLETED'), findsOneWidget);
      expect(find.text('FAILED'), findsOneWidget);
    });

    testWidgets('shows correct queue size value', (tester) async {
      await pumpDashboard(tester, queueSize: 5);
      expect(find.text('5'), findsAtLeast(1));
    });

    testWidgets('shows Recent Tasks header', (tester) async {
      await pumpDashboard(tester);
      expect(find.text('Recent Tasks'), findsOneWidget);
    });

    testWidgets('shows total task count', (tester) async {
      await pumpDashboard(tester);
      expect(find.text('4 total'), findsOneWidget);
    });

    testWidgets('renders task type for each task', (tester) async {
      await pumpDashboard(tester);
      expect(find.text('Generate'), findsOneWidget);
      expect(find.text('Evaluate'), findsOneWidget);
      expect(find.text('Research'), findsOneWidget);
      expect(find.text('Translate'), findsOneWidget);
    });

    testWidgets('shows status badges for tasks', (tester) async {
      await pumpDashboard(tester);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Running'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Failed'), findsOneWidget);
    });

    testWidgets('shows priority badges', (tester) async {
      await pumpDashboard(tester);
      expect(find.text('High'), findsAtLeast(1));
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('Low'), findsOneWidget);
    });

    testWidgets('shows layer name when present', (tester) async {
      await pumpDashboard(tester);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text && w.data != null && w.data!.contains('Layer: Draft'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows worker name when present', (tester) async {
      await pumpDashboard(tester);
      expect(
        find.byWidgetPredicate((w) => w is Text && w.data == 'writer-1'),
        findsOneWidget,
      );
    });

    testWidgets('shows truncated task id', (tester) async {
      await pumpDashboard(tester);
      expect(find.text('aaaaaaaa'), findsOneWidget);
    });

    testWidgets('shows empty message when no tasks', (tester) async {
      await pumpDashboard(tester, tasks: []);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text && w.data != null && w.data!.contains('No tasks yet'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows error message on provider error', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tasksProvider.overrideWith(() => _ErrorTasksNotifier()),
            queueSizeProvider.overrideWith((ref) async => 0),
          ],
          child: const MaterialApp(home: DashboardPage()),
        ),
      );
      await tester.pumpAndSettle();
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

class _ErrorTasksNotifier extends TasksNotifier {
  @override
  Future<List<AppTask>> build() async => throw Exception('db failed');
}
