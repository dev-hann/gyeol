import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/core/theme/app_theme.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/providers/app_providers.dart';
import 'package:gyeol/main.dart';
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
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
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
        child: const GyeolApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('GyeolApp', () {
    testWidgets('renders MaterialApp', (tester) async {
      await pumpApp(tester);
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('has correct title', (tester) async {
      await pumpApp(tester);
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.title, 'Gyeol');
    });

    testWidgets('hides debug banner', (tester) async {
      await pumpApp(tester);
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.debugShowCheckedModeBanner, isFalse);
    });

    testWidgets('uses dark theme from buildAppTheme', (tester) async {
      await pumpApp(tester);
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      final expectedTheme = buildAppTheme();
      expect(materialApp.theme?.brightness, expectedTheme.brightness);
      expect(
        materialApp.theme?.colorScheme.primary,
        expectedTheme.colorScheme.primary,
      );
    });

    testWidgets('home is AppShell', (tester) async {
      await pumpApp(tester);
      expect(find.byType(AppShell), findsOneWidget);
    });

    testWidgets('renders Gyeol title in sidebar', (tester) async {
      await pumpApp(tester);
      expect(find.text('Gyeol'), findsOneWidget);
    });
  });
}
