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

  Future<void> openConfigDialog(WidgetTester tester) async {
    await tester.tap(find.text('Add Provider'));
    await tester.pumpAndSettle();
  }

  group('SettingsPage', () {
    testWidgets('renders Settings title', (tester) async {
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

    testWidgets('renders AI Provider section', (tester) async {
      await pumpSettingsPage(tester);
      expect(find.text('AI Provider'), findsOneWidget);
    });

    testWidgets('renders Add Provider button', (tester) async {
      await pumpSettingsPage(tester);
      expect(find.text('Add Provider'), findsOneWidget);
    });

    testWidgets('renders Generation Defaults section', (tester) async {
      await pumpSettingsPage(tester);
      expect(find.text('Generation Defaults'), findsOneWidget);
    });

    testWidgets('renders default temperature field', (tester) async {
      await pumpSettingsPage(tester);
      await tester.tap(find.text('Generation Defaults'));
      await tester.pumpAndSettle();
      expect(find.text('Temperature'), findsOneWidget);
    });

    testWidgets('renders default max tokens field', (tester) async {
      await pumpSettingsPage(tester);
      await tester.tap(find.text('Generation Defaults'));
      await tester.pumpAndSettle();
      expect(find.text('Max Tokens'), findsOneWidget);
    });

    testWidgets('shows OpenAI as default active provider', (tester) async {
      await pumpSettingsPage(tester);
      expect(find.text('OpenAI'), findsOneWidget);
    });

    testWidgets('shows Not configured for empty API key', (tester) async {
      await pumpSettingsPage(tester);
      expect(find.text('Not configured'), findsOneWidget);
    });

    testWidgets('shows Connected when API key is set', (tester) async {
      await pumpSettingsPage(
        tester,
        settings: const ProviderSettings(
          configs: {
            ProviderType.openAI: OpenAIConfig(apiKey: 'sk-test'),
            ProviderType.anthropic: AnthropicConfig(),
            ProviderType.ollama: OllamaConfig(),
            ProviderType.custom: CustomConfig(),
          },
        ),
      );
      expect(find.text('Connected'), findsOneWidget);
    });

    testWidgets('opens config modal on Add Provider tap', (tester) async {
      await pumpSettingsPage(tester);
      await openConfigDialog(tester);
      expect(find.text('Configure Provider'), findsOneWidget);
      expect(find.text('Platform'), findsOneWidget);
      expect(find.text('API Key'), findsOneWidget);
      expect(find.text('Register'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('modal has Platform dropdown with all providers', (
      tester,
    ) async {
      await pumpSettingsPage(tester);
      await openConfigDialog(tester);
      await tester.tap(find.byType(DropdownButton<ProviderType>));
      await tester.pumpAndSettle();
      expect(find.text('OpenAI'), findsWidgets);
      expect(find.text('Anthropic'), findsOneWidget);
      expect(find.text('Ollama'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
    });

    testWidgets('modal does not show Model selector', (tester) async {
      await pumpSettingsPage(tester);
      await openConfigDialog(tester);
      expect(find.text('Model'), findsNothing);
    });

    testWidgets('cancel dismisses modal', (tester) async {
      await pumpSettingsPage(tester);
      await openConfigDialog(tester);
      expect(find.text('Configure Provider'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Configure Provider'), findsNothing);
    });

    testWidgets('switches to Anthropic hides Base URL shows API Key', (
      tester,
    ) async {
      await pumpSettingsPage(tester);
      await openConfigDialog(tester);
      await tester.tap(find.byType(DropdownButton<ProviderType>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anthropic').last);
      await tester.pumpAndSettle();
      expect(find.text('Base URL'), findsNothing);
      expect(find.text('API Key'), findsOneWidget);
    });

    testWidgets('switches to Ollama shows Base URL hides API Key', (
      tester,
    ) async {
      await pumpSettingsPage(tester);
      await openConfigDialog(tester);
      await tester.tap(find.byType(DropdownButton<ProviderType>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ollama').last);
      await tester.pumpAndSettle();
      expect(find.text('Base URL'), findsOneWidget);
      expect(find.text('API Key'), findsNothing);
    });

    testWidgets('switches to Custom shows Base URL and API Key', (
      tester,
    ) async {
      await pumpSettingsPage(tester);
      await openConfigDialog(tester);
      await tester.tap(find.byType(DropdownButton<ProviderType>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Custom').last);
      await tester.pumpAndSettle();
      expect(find.text('Base URL'), findsOneWidget);
      expect(find.text('API Key'), findsOneWidget);
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

  @override
  Future<void> save(ProviderSettings settings) async {
    state = AsyncData(settings);
  }
}

class _ErrorSettingsNotifier extends SettingsNotifier {
  @override
  Future<ProviderSettings> build() async => throw Exception('db failed');
}
