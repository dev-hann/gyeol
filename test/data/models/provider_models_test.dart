import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/models/provider_models.dart';

void main() {
  group('ProviderType', () {
    test('has four values', () {
      expect(ProviderType.values, hasLength(4));
      expect(
        ProviderType.values,
        containsAll([
          ProviderType.openAI,
          ProviderType.anthropic,
          ProviderType.ollama,
          ProviderType.custom,
        ]),
      );
    });
  });

  group('CustomApiFormat', () {
    test('has three values', () {
      expect(CustomApiFormat.values, hasLength(3));
      expect(
        CustomApiFormat.values,
        containsAll([
          CustomApiFormat.openAICompatible,
          CustomApiFormat.anthropicCompatible,
          CustomApiFormat.ollamaCompatible,
        ]),
      );
    });
  });

  group('OpenAIConfig', () {
    test('default constructor sets defaults', () {
      const config = OpenAIConfig();
      expect(config.type, ProviderType.openAI);
      expect(config.apiKey, '');
      expect(config.model, 'gpt-4o');
      expect(config.isConfigured, isFalse);
    });

    test('isConfigured true when apiKey non-empty', () {
      const config = OpenAIConfig(apiKey: 'sk-test');
      expect(config.isConfigured, isTrue);
    });

    test('toJson returns correct map', () {
      const config = OpenAIConfig(apiKey: 'sk-test', model: 'gpt-4o-mini');
      final json = config.toJson();
      expect(json, {
        'type': 'openai',
        'apiKey': 'sk-test',
        'model': 'gpt-4o-mini',
      });
    });

    test('copyWith overrides specified fields', () {
      const original = OpenAIConfig(apiKey: 'old');
      final copied = original.copyWith(apiKey: 'new', model: 'gpt-4o-mini');
      expect(copied.apiKey, 'new');
      expect(copied.model, 'gpt-4o-mini');
    });

    test('copyWith preserves unspecified fields', () {
      const original = OpenAIConfig(apiKey: 'sk');
      final copied = original.copyWith();
      expect(copied.apiKey, original.apiKey);
      expect(copied.model, original.model);
    });
  });

  group('AnthropicConfig', () {
    test('default constructor sets defaults', () {
      const config = AnthropicConfig();
      expect(config.type, ProviderType.anthropic);
      expect(config.apiKey, '');
      expect(config.model, 'claude-sonnet-4-20250514');
      expect(config.isConfigured, isFalse);
    });

    test('isConfigured true when apiKey non-empty', () {
      const config = AnthropicConfig(apiKey: 'sk-ant-test');
      expect(config.isConfigured, isTrue);
    });

    test('toJson returns correct map', () {
      const config = AnthropicConfig(apiKey: 'key', model: 'claude-3');
      final json = config.toJson();
      expect(json, {'type': 'anthropic', 'apiKey': 'key', 'model': 'claude-3'});
    });

    test('copyWith overrides specified fields', () {
      const original = AnthropicConfig(apiKey: 'old');
      final copied = original.copyWith(apiKey: 'new');
      expect(copied.apiKey, 'new');
      expect(copied.model, original.model);
    });
  });

  group('OllamaConfig', () {
    test('default constructor sets defaults', () {
      const config = OllamaConfig();
      expect(config.type, ProviderType.ollama);
      expect(config.baseUrl, '');
      expect(config.model, 'llama3');
      expect(config.isConfigured, isFalse);
    });

    test('isConfigured true when baseUrl non-empty', () {
      const config = OllamaConfig(baseUrl: 'http://localhost:11434');
      expect(config.isConfigured, isTrue);
    });

    test('toJson returns correct map', () {
      const config = OllamaConfig(
        baseUrl: 'http://localhost:11434',
        model: 'mixtral',
      );
      final json = config.toJson();
      expect(json, {
        'type': 'ollama',
        'baseUrl': 'http://localhost:11434',
        'model': 'mixtral',
      });
    });

    test('copyWith overrides specified fields', () {
      const original = OllamaConfig(baseUrl: 'http://old');
      final copied = original.copyWith(baseUrl: 'http://new');
      expect(copied.baseUrl, 'http://new');
      expect(copied.model, original.model);
    });
  });

  group('CustomConfig', () {
    test('default constructor sets defaults', () {
      const config = CustomConfig();
      expect(config.type, ProviderType.custom);
      expect(config.baseUrl, '');
      expect(config.apiKey, '');
      expect(config.model, '');
      expect(config.apiFormat, CustomApiFormat.openAICompatible);
      expect(config.isConfigured, isFalse);
    });

    test('isConfigured true when baseUrl non-empty', () {
      const config = CustomConfig(baseUrl: 'http://custom.api');
      expect(config.isConfigured, isTrue);
    });

    test('toJson returns correct map for openAI format', () {
      const config = CustomConfig(
        baseUrl: 'http://api',
        apiKey: 'key',
        model: 'custom-model',
      );
      final json = config.toJson();
      expect(json, {
        'type': 'custom',
        'baseUrl': 'http://api',
        'apiKey': 'key',
        'model': 'custom-model',
        'apiFormat': 'openai',
      });
    });

    test('toJson returns correct map for anthropic format', () {
      const config = CustomConfig(
        apiFormat: CustomApiFormat.anthropicCompatible,
      );
      expect(config.toJson()['apiFormat'], 'anthropic');
    });

    test('toJson returns correct map for ollama format', () {
      const config = CustomConfig(apiFormat: CustomApiFormat.ollamaCompatible);
      expect(config.toJson()['apiFormat'], 'ollama');
    });

    test('copyWith overrides specified fields', () {
      const original = CustomConfig(
        baseUrl: 'http://old',
        apiKey: 'old-key',
        model: 'old-model',
      );
      final copied = original.copyWith(
        baseUrl: 'http://new',
        apiFormat: CustomApiFormat.anthropicCompatible,
      );
      expect(copied.baseUrl, 'http://new');
      expect(copied.apiKey, original.apiKey);
      expect(copied.model, original.model);
      expect(copied.apiFormat, CustomApiFormat.anthropicCompatible);
    });
  });

  group('ProviderConfig.fromJson', () {
    test('parses openai config', () {
      final config = ProviderConfig.fromJson({
        'type': 'openai',
        'apiKey': 'sk-test',
        'model': 'gpt-4o-mini',
      });
      expect(config, isA<OpenAIConfig>());
      expect((config as OpenAIConfig).apiKey, 'sk-test');
      expect(config.model, 'gpt-4o-mini');
    });

    test('parses anthropic config', () {
      final config = ProviderConfig.fromJson({
        'type': 'anthropic',
        'apiKey': 'sk-ant',
        'model': 'claude-3',
      });
      expect(config, isA<AnthropicConfig>());
      expect((config as AnthropicConfig).apiKey, 'sk-ant');
      expect(config.model, 'claude-3');
    });

    test('parses ollama config', () {
      final config = ProviderConfig.fromJson({
        'type': 'ollama',
        'baseUrl': 'http://localhost:11434',
        'model': 'llama3',
      });
      expect(config, isA<OllamaConfig>());
      expect((config as OllamaConfig).baseUrl, 'http://localhost:11434');
      expect(config.model, 'llama3');
    });

    test('parses custom config with openAI format', () {
      final config = ProviderConfig.fromJson({
        'type': 'custom',
        'baseUrl': 'http://custom',
        'apiKey': 'key',
        'model': 'model',
        'apiFormat': 'openai',
      });
      expect(config, isA<CustomConfig>());
      final custom = config as CustomConfig;
      expect(custom.baseUrl, 'http://custom');
      expect(custom.apiKey, 'key');
      expect(custom.apiFormat, CustomApiFormat.openAICompatible);
    });

    test('parses custom config with anthropic format', () {
      final config = ProviderConfig.fromJson({
        'type': 'custom',
        'apiFormat': 'anthropic',
      });
      expect(
        (config as CustomConfig).apiFormat,
        CustomApiFormat.anthropicCompatible,
      );
    });

    test('parses custom config with ollama format', () {
      final config = ProviderConfig.fromJson({
        'type': 'custom',
        'apiFormat': 'ollama',
      });
      expect(
        (config as CustomConfig).apiFormat,
        CustomApiFormat.ollamaCompatible,
      );
    });

    test('defaults to openai for unknown type', () {
      final config = ProviderConfig.fromJson({'type': 'unknown'});
      expect(config, isA<OpenAIConfig>());
    });

    test('handles missing fields with defaults', () {
      final config = ProviderConfig.fromJson({});
      expect(config, isA<OpenAIConfig>());
      expect((config as OpenAIConfig).apiKey, '');
      expect(config.model, 'gpt-4o');
    });
  });

  group('ProviderSettings', () {
    test('default constructor sets correct defaults', () {
      const settings = ProviderSettings();
      expect(settings.activeProvider, ProviderType.openAI);
      expect(settings.defaultTemperature, 0.7);
      expect(settings.defaultMaxTokens, 4096);
      expect(settings.defaultTopP, 1.0);
      expect(settings.defaultFrequencyPenalty, 0.0);
      expect(settings.defaultPresencePenalty, 0.0);
      expect(settings.defaultStopSequences, isEmpty);
      expect(settings.defaultTimeout, 60000);
      expect(settings.configs, hasLength(4));
    });

    test('configs contain all provider types', () {
      const settings = ProviderSettings();
      expect(settings.configs.containsKey(ProviderType.openAI), isTrue);
      expect(settings.configs.containsKey(ProviderType.anthropic), isTrue);
      expect(settings.configs.containsKey(ProviderType.ollama), isTrue);
      expect(settings.configs.containsKey(ProviderType.custom), isTrue);
    });

    test('active returns config for activeProvider', () {
      const settings = ProviderSettings();
      expect(settings.active, isA<OpenAIConfig>());
    });

    test('active falls back to first config if missing', () {
      const settings = ProviderSettings(
        activeProvider: ProviderType.anthropic,
        configs: {ProviderType.openAI: OpenAIConfig()},
      );
      expect(settings.active, isA<OpenAIConfig>());
    });

    test('configured returns only configured providers', () {
      const settings = ProviderSettings(
        configs: {
          ProviderType.openAI: OpenAIConfig(apiKey: 'sk'),
          ProviderType.anthropic: AnthropicConfig(),
          ProviderType.ollama: OllamaConfig(baseUrl: 'http://ollama'),
          ProviderType.custom: CustomConfig(),
        },
      );
      final configured = settings.configured;
      expect(configured, hasLength(2));
      expect(configured[0], isA<OpenAIConfig>());
      expect(configured[1], isA<OllamaConfig>());
    });

    test('isProviderConfigured returns correct state', () {
      const settings = ProviderSettings(
        configs: {
          ProviderType.openAI: OpenAIConfig(apiKey: 'sk'),
          ProviderType.anthropic: AnthropicConfig(),
        },
      );
      expect(settings.isProviderConfigured(ProviderType.openAI), isTrue);
      expect(settings.isProviderConfigured(ProviderType.anthropic), isFalse);
      expect(settings.isProviderConfigured(ProviderType.ollama), isFalse);
    });

    test('toJson and fromJson roundtrip', () {
      const settings = ProviderSettings(
        activeProvider: ProviderType.anthropic,
        configs: {
          ProviderType.openAI: OpenAIConfig(apiKey: 'sk-test'),
          ProviderType.anthropic: AnthropicConfig(
            apiKey: 'sk-ant',
            model: 'claude-3',
          ),
          ProviderType.ollama: OllamaConfig(baseUrl: 'http://ollama'),
          ProviderType.custom: CustomConfig(
            baseUrl: 'http://custom',
            apiKey: 'key',
            model: 'model',
            apiFormat: CustomApiFormat.anthropicCompatible,
          ),
        },
        defaultTemperature: 0.5,
        defaultMaxTokens: 2048,
        defaultTopP: 0.9,
        defaultFrequencyPenalty: 0.1,
        defaultPresencePenalty: 0.2,
        defaultStopSequences: ['stop1', 'stop2'],
        defaultTimeout: 30000,
      );
      final json = settings.toJson();
      final restored = ProviderSettings.fromJson(json);

      expect(restored.activeProvider, ProviderType.anthropic);
      expect(restored.defaultTemperature, 0.5);
      expect(restored.defaultMaxTokens, 2048);
      expect(restored.defaultTopP, 0.9);
      expect(restored.defaultFrequencyPenalty, 0.1);
      expect(restored.defaultPresencePenalty, 0.2);
      expect(restored.defaultStopSequences, ['stop1', 'stop2']);
      expect(restored.defaultTimeout, 30000);
    });

    test('fromJson handles partial json with defaults', () {
      final settings = ProviderSettings.fromJson({'activeProvider': 'openAI'});
      expect(settings.activeProvider, ProviderType.openAI);
      expect(settings.defaultTemperature, 0.7);
      expect(settings.defaultMaxTokens, 4096);
      expect(settings.configs[ProviderType.openAI], isA<OpenAIConfig>());
    });

    test('fromJson parses configs from json', () {
      final settings = ProviderSettings.fromJson({
        'activeProvider': 'openAI',
        'configs': {
          'openAI': {
            'type': 'openai',
            'apiKey': 'sk-from-json',
            'model': 'gpt-4o-mini',
          },
        },
      });
      final openai = settings.configs[ProviderType.openAI]! as OpenAIConfig;
      expect(openai.apiKey, 'sk-from-json');
      expect(openai.model, 'gpt-4o-mini');
    });

    test('fromJson handles unknown activeProvider', () {
      final settings = ProviderSettings.fromJson({'activeProvider': 'unknown'});
      expect(settings.activeProvider, ProviderType.openAI);
    });

    test('fromJson handles Anthropic activeProvider string', () {
      final settings = ProviderSettings.fromJson({
        'activeProvider': 'Anthropic',
      });
      expect(settings.activeProvider, ProviderType.anthropic);
    });

    test('fromJson handles Ollama activeProvider string', () {
      final settings = ProviderSettings.fromJson({'activeProvider': 'Ollama'});
      expect(settings.activeProvider, ProviderType.ollama);
    });

    test('fromJson handles Custom activeProvider string', () {
      final settings = ProviderSettings.fromJson({'activeProvider': 'Custom'});
      expect(settings.activeProvider, ProviderType.custom);
    });

    test('copyWith overrides specified fields', () {
      const original = ProviderSettings();
      final copied = original.copyWith(
        activeProvider: ProviderType.ollama,
        defaultTemperature: 0.3,
      );
      expect(copied.activeProvider, ProviderType.ollama);
      expect(copied.defaultTemperature, 0.3);
      expect(copied.defaultMaxTokens, original.defaultMaxTokens);
    });

    test('copyWith preserves unspecified fields', () {
      const original = ProviderSettings(
        activeProvider: ProviderType.anthropic,
        defaultTemperature: 0.5,
      );
      final copied = original.copyWith();
      expect(copied.activeProvider, original.activeProvider);
      expect(copied.defaultTemperature, original.defaultTemperature);
    });

    test('withConfig updates config for given type', () {
      const original = ProviderSettings();
      final updated = original.withConfig(
        const OpenAIConfig(apiKey: 'new-key', model: 'gpt-4o-mini'),
      );
      final openai = updated.configs[ProviderType.openAI]! as OpenAIConfig;
      expect(openai.apiKey, 'new-key');
      expect(openai.model, 'gpt-4o-mini');
    });

    test('withConfig preserves other configs', () {
      const original = ProviderSettings();
      final updated = original.withConfig(const OpenAIConfig(apiKey: 'sk'));
      expect(updated.configs[ProviderType.anthropic], isA<AnthropicConfig>());
      expect(updated.configs[ProviderType.ollama], isA<OllamaConfig>());
      expect(updated.configs[ProviderType.custom], isA<CustomConfig>());
    });

    test('toJson activeProvider serialization', () {
      expect(const ProviderSettings().toJson()['activeProvider'], 'openAI');
      expect(
        const ProviderSettings(
          activeProvider: ProviderType.anthropic,
        ).toJson()['activeProvider'],
        'Anthropic',
      );
      expect(
        const ProviderSettings(
          activeProvider: ProviderType.ollama,
        ).toJson()['activeProvider'],
        'Ollama',
      );
      expect(
        const ProviderSettings(
          activeProvider: ProviderType.custom,
        ).toJson()['activeProvider'],
        'Custom',
      );
    });
  });
}
