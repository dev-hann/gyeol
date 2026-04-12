import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/models/provider_models.dart';
import 'package:gyeol/data/providers/core_providers.dart';
import 'package:gyeol/data/providers/settings_provider.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('SettingsNotifier', () {
    test('build returns default settings when no saved settings', () async {
      final settings = await container.read(settingsProvider.future);
      expect(settings.activeProvider, ProviderType.openAI);
      expect(settings.defaultTemperature, 0.7);
      expect(settings.defaultMaxTokens, 4096);
      expect(settings.defaultTopP, 1.0);
      expect(settings.defaultTimeout, 60000);
    });

    test('build returns saved settings from repository', () async {
      final repo = container.read(repositoryProvider);
      const saved = ProviderSettings(
        activeProvider: ProviderType.anthropic,
        defaultTemperature: 0.3,
        defaultMaxTokens: 2048,
      );
      await repo.settings.saveSettings(saved);

      final freshContainer = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(freshContainer.dispose);

      final settings = await freshContainer.read(settingsProvider.future);
      expect(settings.activeProvider, ProviderType.anthropic);
      expect(settings.defaultTemperature, 0.3);
      expect(settings.defaultMaxTokens, 2048);
    });

    test('save persists and updates state', () async {
      final notifier = container.read(settingsProvider.notifier);
      const updated = ProviderSettings(
        activeProvider: ProviderType.ollama,
        defaultTemperature: 0.9,
      );
      await notifier.save(updated);

      final settings = await container.read(settingsProvider.future);
      expect(settings.activeProvider, ProviderType.ollama);
      expect(settings.defaultTemperature, 0.9);
    });

    test('save persists across container recreation', () async {
      final notifier = container.read(settingsProvider.notifier);
      const custom = ProviderSettings(
        activeProvider: ProviderType.custom,
        defaultMaxTokens: 8192,
      );
      await notifier.save(custom);

      final freshContainer = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(freshContainer.dispose);

      final settings = await freshContainer.read(settingsProvider.future);
      expect(settings.activeProvider, ProviderType.custom);
      expect(settings.defaultMaxTokens, 8192);
    });

    test('save with updated configs preserves all provider configs', () async {
      final notifier = container.read(settingsProvider.notifier);
      final updated = const ProviderSettings().withConfig(
        const OpenAIConfig(apiKey: 'sk-test-key', model: 'gpt-4o-mini'),
      );
      await notifier.save(updated);

      final settings = await container.read(settingsProvider.future);
      final openai = settings.configs[ProviderType.openAI];
      if (openai is! OpenAIConfig) fail('Expected OpenAIConfig');
      expect(openai.apiKey, 'sk-test-key');
      expect(openai.model, 'gpt-4o-mini');
      expect(settings.configs, contains(ProviderType.anthropic));
      expect(settings.configs, contains(ProviderType.ollama));
      expect(settings.configs, contains(ProviderType.custom));
    });

    test('default settings have all four provider types', () async {
      final settings = await container.read(settingsProvider.future);
      expect(settings.configs.length, 4);
      expect(settings.configs.keys, containsAll(ProviderType.values));
    });
  });
}
