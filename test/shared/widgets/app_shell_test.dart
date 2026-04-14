import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/providers/app_providers.dart';
import 'package:gyeol/features/chat/chat_panel.dart';
import 'package:gyeol/shared/widgets/app_shell.dart';

class _FakeTasksNotifier extends TasksNotifier {
  _FakeTasksNotifier(this._tasks);

  final List<AppTask> _tasks;

  @override
  Future<List<AppTask>> build() async => _tasks;
}

class _FakeLayersNotifier extends LayersNotifier {
  @override
  Future<List<LayerDefinition>> build() async => [];
}

class _FakeWorkersNotifier extends WorkersNotifier {
  @override
  Future<List<WorkerDefinition>> build() async => [];
}

class _FakeThreadsNotifier extends ThreadsNotifier {
  @override
  Future<List<ThreadDefinition>> build() async => [];
}

class _FakeSettingsNotifier extends SettingsNotifier {
  @override
  Future<ProviderSettings> build() async => const ProviderSettings();
}

class _FakeLogsNotifier extends LogsNotifier {
  @override
  Future<List<ExecutionLog>> build() async => [];
}

class _FakeConversationsNotifier extends ConversationsNotifier {
  @override
  Future<List<ChatConversation>> build() async => [];
}

void main() {
  Future<void> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tasksProvider.overrideWith(() => _FakeTasksNotifier([])),
          layersProvider.overrideWith(_FakeLayersNotifier.new),
          threadsProvider.overrideWith(_FakeThreadsNotifier.new),
          workersProvider.overrideWith(_FakeWorkersNotifier.new),
          settingsProvider.overrideWith(_FakeSettingsNotifier.new),
          logsProvider.overrideWith(_FakeLogsNotifier.new),
          queueSizeProvider.overrideWith((ref) async => 0),
          conversationsProvider.overrideWith(_FakeConversationsNotifier.new),
          chatSendingProvider.overrideWith((ref) => false),
          selectedConversationIdProvider.overrideWith((ref) => null),
        ],
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('AppShell', () {
    testWidgets('renders Gyeol title', (tester) async {
      await pumpShell(tester);
      expect(find.text('Gyeol'), findsOneWidget);
    });

    testWidgets('renders subtitle', (tester) async {
      await pumpShell(tester);
      expect(find.text('AI Multi-Layer Worker'), findsOneWidget);
    });

    testWidgets('renders all five navigation labels', (tester) async {
      await pumpShell(tester);
      expect(find.text('Dashboard'), findsAtLeast(1));
      expect(find.text('Monitoring'), findsAtLeast(1));
      expect(find.text('Threads'), findsAtLeast(1));
      expect(find.text('Chat'), findsAtLeast(1));
      expect(find.text('Settings'), findsAtLeast(1));
    });

    testWidgets('renders Run Scheduler button', (tester) async {
      await pumpShell(tester);
      expect(find.text('Run Scheduler'), findsOneWidget);
    });

    testWidgets('does not render Open Chat button', (tester) async {
      await pumpShell(tester);
      expect(find.text('Open Chat'), findsNothing);
      expect(find.text('Hide Chat'), findsNothing);
    });

    testWidgets('tapping Settings updates visible page', (tester) async {
      await pumpShell(tester);
      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      expect(find.byType(AppShell), findsOneWidget);
    });

    testWidgets('tapping Chat shows chat page', (tester) async {
      await pumpShell(tester);
      await tester.tap(find.text('Chat').last);
      await tester.pumpAndSettle();
      expect(find.byType(ChatPanel), findsOneWidget);
    });

    testWidgets('uses IndexedStack for page switching', (tester) async {
      await pumpShell(tester);
      expect(find.byType(IndexedStack), findsOneWidget);
    });

    testWidgets('sidebar contains play arrow icon in Run button', (
      tester,
    ) async {
      await pumpShell(tester);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('nav items contain expected icons', (tester) async {
      await pumpShell(tester);
      expect(find.byIcon(Icons.dashboard_outlined), findsAtLeast(1));
      expect(find.byIcon(Icons.show_chart), findsAtLeast(1));
      expect(find.byIcon(Icons.account_tree_outlined), findsAtLeast(1));
      expect(find.byIcon(Icons.chat_outlined), findsAtLeast(1));
      expect(find.byIcon(Icons.settings_outlined), findsAtLeast(1));
    });

    testWidgets('no FloatingActionButton present', (tester) async {
      await pumpShell(tester);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('uses Row layout for sidebar + content', (tester) async {
      await pumpShell(tester);
      expect(find.byType(Row), findsAtLeast(1));
    });
  });
}
