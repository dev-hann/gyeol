import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/repositories/settings_repository.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = SettingsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('SettingsRepository', () {
    test('getSettings returns defaults when no settings saved', () async {
      final settings = await repo.getSettings();
      expect(settings.activeProvider, ProviderType.openAI);
      expect(settings.defaultTemperature, 0.7);
      expect(settings.defaultMaxTokens, 4096);
    });

    test('saveSettings + getSettings round-trips ProviderSettings', () async {
      const original = ProviderSettings(
        activeProvider: ProviderType.anthropic,
        configs: {
          ProviderType.openAI: OpenAIConfig(apiKey: 'sk-test', model: 'gpt-4'),
          ProviderType.anthropic: AnthropicConfig(
            apiKey: 'ant-key',
            model: 'claude-3',
          ),
          ProviderType.ollama: OllamaConfig(baseUrl: 'http://localhost:11434'),
          ProviderType.custom: CustomConfig(
            baseUrl: 'http://custom:8080',
            apiKey: 'ck',
            model: 'cm',
            apiFormat: CustomApiFormat.anthropicCompatible,
          ),
        },
        defaultTemperature: 0.5,
        defaultMaxTokens: 2048,
      );

      await repo.saveSettings(original);
      final restored = await repo.getSettings();

      expect(restored.activeProvider, ProviderType.anthropic);
      expect(restored.defaultTemperature, 0.5);
      expect(restored.defaultMaxTokens, 2048);

      final openai = restored.configs[ProviderType.openAI]! as OpenAIConfig;
      expect(openai.apiKey, 'sk-test');
      expect(openai.model, 'gpt-4');

      final anthropic =
          restored.configs[ProviderType.anthropic]! as AnthropicConfig;
      expect(anthropic.apiKey, 'ant-key');
      expect(anthropic.model, 'claude-3');

      final ollama = restored.configs[ProviderType.ollama]! as OllamaConfig;
      expect(ollama.baseUrl, 'http://localhost:11434');

      final custom = restored.configs[ProviderType.custom]! as CustomConfig;
      expect(custom.apiFormat, CustomApiFormat.anthropicCompatible);
    });

    test('getSettings returns defaults on malformed JSON', () async {
      await db.saveSettings('not-valid-json{{{');
      final settings = await repo.getSettings();
      expect(settings.activeProvider, ProviderType.openAI);
    });

    test('getSettings returns defaults on non-map JSON', () async {
      await db.saveSettings('"just_a_string"');
      final settings = await repo.getSettings();
      expect(settings.activeProvider, ProviderType.openAI);
    });

    test('saveSettings upserts existing settings', () async {
      await repo.saveSettings(const ProviderSettings());
      await repo.saveSettings(
        const ProviderSettings(activeProvider: ProviderType.ollama),
      );

      final settings = await repo.getSettings();
      expect(settings.activeProvider, ProviderType.ollama);
    });
  });
}
