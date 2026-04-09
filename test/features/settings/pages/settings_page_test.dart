import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/providers/app_providers.dart';
import 'package:gyeol/features/settings/pages/settings_page.dart';

ProviderSettings fakeSettings() => const ProviderSettings();

void main() {
  Future<void> pumpSettingsPage(
    WidgetTester tester, {
    ProviderSettings? settings,
  }) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            () => _FakeSettingsNotifier(settings ?? fakeSettings()),
          ),
        ],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  group('SettingsPage', () {
    testWidgets('renders PageHeader with Settings title', (tester) async {
      await pumpSettingsPage(tester);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('renders description text', (tester) async {
      await pumpSettingsPage(tester);
      expect(
        find.text('Configure AI provider and system settings'),
        findsOneWidget,
      );
    });

    testWidgets('renders Save Settings button', (tester) async {
      await pumpSettingsPage(tester);
      expect(find.text('Save Settings'), findsOneWidget);
    });

    testWidgets('renders AI Provider section', (tester) async {
      await pumpSettingsPage(tester);
      expect(find.text('AI Provider'), findsOneWidget);
    });

    testWidgets('renders OpenAI section', (tester) async {
      await pumpSettingsPage(tester);
      expect(find.text('OpenAI'), findsAtLeast(1));
    });

    testWidgets('renders Anthropic section', (tester) async {
      await pumpSettingsPage(tester);
      expect(find.text('Anthropic'), findsOneWidget);
    });

    testWidgets('renders Ollama section', (tester) async {
      await pumpSettingsPage(tester);
      expect(find.text('Ollama (Local)'), findsOneWidget);
    });

    testWidgets('renders Defaults section', (tester) async {
      await pumpSettingsPage(tester);
      expect(find.text('Defaults'), findsOneWidget);
    });

    testWidgets('renders Active Provider dropdown', (tester) async {
      await pumpSettingsPage(tester);
      expect(find.text('Active Provider'), findsOneWidget);
    });

    testWidgets('renders default temperature field', (tester) async {
      await pumpSettingsPage(tester);
      expect(find.text('Default Temperature'), findsOneWidget);
    });

    testWidgets('renders default max tokens field', (tester) async {
      await pumpSettingsPage(tester);
      expect(find.text('Default Max Tokens'), findsOneWidget);
    });

    testWidgets('renders API Key label in OpenAI section', (tester) async {
      await pumpSettingsPage(tester);
      final apiKeyLabels = find.text('API Key');
      expect(apiKeyLabels, findsAtLeast(2));
    });

    testWidgets('renders Model labels for providers', (tester) async {
      await pumpSettingsPage(tester);
      final modelLabels = find.text('Model');
      expect(modelLabels, findsAtLeast(3));
    });

    testWidgets('renders Base URL labels for Ollama and Custom', (
      tester,
    ) async {
      await pumpSettingsPage(tester);
      expect(find.text('Base URL'), findsNWidgets(2));
    });

    testWidgets('shows error on provider error', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith(_ErrorSettingsNotifier.new),
          ],
          child: const MaterialApp(home: SettingsPage()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Error:'), findsOneWidget);
    });
  });
}

class _FakeSettingsNotifier extends SettingsNotifier {
  _FakeSettingsNotifier(this._settings);
  final ProviderSettings _settings;

  @override
  Future<ProviderSettings> build() async => _settings;
}

class _ErrorSettingsNotifier extends SettingsNotifier {
  @override
  Future<ProviderSettings> build() async => throw Exception('db failed');
}
