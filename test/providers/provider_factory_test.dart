import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/providers/lllm_provider.dart';
import 'package:gyeol/providers/provider_factory.dart';

void main() {
  group('createLlmProvider', () {
    test('creates OpenAIProvider for OpenAIConfig', () {
      const settings = ProviderSettings(
        configs: {
          ProviderType.openAI: OpenAIConfig(apiKey: 'sk-test', model: 'gpt-4'),
          ProviderType.anthropic: AnthropicConfig(),
          ProviderType.ollama: OllamaConfig(),
          ProviderType.custom: CustomConfig(),
        },
      );
      final provider = createLlmProvider(settings);
      expect(provider, isA<LlmProvider>());
      provider.close();
    });

    test('creates AnthropicProvider for AnthropicConfig', () {
      const settings = ProviderSettings(
        activeProvider: ProviderType.anthropic,
        configs: {
          ProviderType.openAI: OpenAIConfig(),
          ProviderType.anthropic: AnthropicConfig(
            apiKey: 'sk-ant-test',
            model: 'claude-3',
          ),
          ProviderType.ollama: OllamaConfig(),
          ProviderType.custom: CustomConfig(),
        },
      );
      final provider = createLlmProvider(settings);
      expect(provider, isA<LlmProvider>());
      provider.close();
    });

    test('creates OllamaProvider for OllamaConfig', () {
      const settings = ProviderSettings(
        activeProvider: ProviderType.ollama,
        configs: {
          ProviderType.openAI: OpenAIConfig(),
          ProviderType.anthropic: AnthropicConfig(),
          ProviderType.ollama: OllamaConfig(baseUrl: 'http://localhost:11434'),
          ProviderType.custom: CustomConfig(),
        },
      );
      final provider = createLlmProvider(settings);
      expect(provider, isA<LlmProvider>());
      provider.close();
    });

    test('creates CustomProvider for CustomConfig', () {
      const settings = ProviderSettings(
        activeProvider: ProviderType.custom,
        configs: {
          ProviderType.openAI: OpenAIConfig(),
          ProviderType.anthropic: AnthropicConfig(),
          ProviderType.ollama: OllamaConfig(),
          ProviderType.custom: CustomConfig(
            baseUrl: 'http://custom.api/v1',
            apiKey: 'custom-key',
            model: 'custom-model',
          ),
        },
      );
      final provider = createLlmProvider(settings);
      expect(provider, isA<LlmProvider>());
      provider.close();
    });

    test('uses default settings for temperature and maxTokens', () {
      const settings = ProviderSettings(
        defaultTemperature: 0.5,
        defaultMaxTokens: 2048,
        defaultTopP: 0.9,
        configs: {
          ProviderType.openAI: OpenAIConfig(apiKey: 'sk-test'),
          ProviderType.anthropic: AnthropicConfig(),
          ProviderType.ollama: OllamaConfig(),
          ProviderType.custom: CustomConfig(),
        },
      );
      final provider = createLlmProvider(settings);
      expect(provider, isA<LlmProvider>());
      provider.close();
    });
  });
}
