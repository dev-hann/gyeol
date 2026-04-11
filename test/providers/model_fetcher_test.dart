import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/providers/model_fetcher.dart';

void main() {
  group('ModelFetcher', () {
    test('fetchModels returns Anthropic hardcoded models', () async {
      final models = await ModelFetcher.fetchModels(
        provider: ProviderType.anthropic,
      );
      expect(models, isNotEmpty);
      expect(models, contains('claude-sonnet-4-20250514'));
      expect(models, contains('claude-3-5-sonnet-20241022'));
      expect(models, contains('claude-3-haiku-20240307'));
      expect(models, contains('claude-3-opus-20240229'));
    });

    test('fetchModels returns empty for empty OpenAI key', () async {
      final models = await ModelFetcher.fetchModels(
        provider: ProviderType.openAI,
        apiKey: '',
      );
      expect(models, isEmpty);
    });

    test(
      'fetchModels returns Anthropic models for custom anthropic format',
      () async {
        final models = await ModelFetcher.fetchModels(
          provider: ProviderType.custom,
          apiFormat: CustomApiFormat.anthropicCompatible,
        );
        expect(models, isNotEmpty);
        expect(models, contains('claude-sonnet-4-20250514'));
      },
    );

    test('fetchModels returns empty for unreachable Ollama', () async {
      final models = await ModelFetcher.fetchModels(
        provider: ProviderType.ollama,
        baseUrl: 'http://0.0.0.0:1',
      );
      expect(models, isEmpty);
    });

    test('fetchModels returns empty for unreachable custom OpenAI', () async {
      final models = await ModelFetcher.fetchModels(
        provider: ProviderType.custom,
        baseUrl: 'http://0.0.0.0:1',
        apiFormat: CustomApiFormat.openAICompatible,
      );
      expect(models, isEmpty);
    });

    test('fetchModels returns empty for unreachable custom Ollama', () async {
      final models = await ModelFetcher.fetchModels(
        provider: ProviderType.custom,
        baseUrl: 'http://0.0.0.0:1',
        apiFormat: CustomApiFormat.ollamaCompatible,
      );
      expect(models, isEmpty);
    });
  });
}
