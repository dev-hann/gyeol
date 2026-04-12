import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/providers/anthropic_provider.dart';
import 'package:gyeol/providers/custom_provider.dart';
import 'package:gyeol/providers/lllm_provider.dart';
import 'package:gyeol/providers/ollama_provider.dart';
import 'package:gyeol/providers/openai_provider.dart';

LlmProvider createLlmProvider(ProviderSettings settings) {
  final config = settings.active;
  return switch (config) {
    OpenAIConfig(:final apiKey) => OpenAIProvider(
      apiKey: apiKey,
      model: config.model,
      temperature: settings.defaultTemperature,
      maxTokens: settings.defaultMaxTokens,
      topP: settings.defaultTopP,
      frequencyPenalty: settings.defaultFrequencyPenalty,
      presencePenalty: settings.defaultPresencePenalty,
      stopSequences: settings.defaultStopSequences,
      timeout: settings.defaultTimeout,
    ),
    AnthropicConfig(:final apiKey) => AnthropicProvider(
      apiKey: apiKey,
      model: config.model,
      temperature: settings.defaultTemperature,
      maxTokens: settings.defaultMaxTokens,
      topP: settings.defaultTopP,
      stopSequences: settings.defaultStopSequences,
      timeout: settings.defaultTimeout,
    ),
    OllamaConfig(:final baseUrl) => OllamaProvider(
      baseUrl: baseUrl,
      model: config.model,
      temperature: settings.defaultTemperature,
      maxTokens: settings.defaultMaxTokens,
      topP: settings.defaultTopP,
      timeout: settings.defaultTimeout,
    ),
    CustomConfig(:final baseUrl, :final apiKey, :final apiFormat) =>
      CustomProvider(
        baseUrl: baseUrl,
        model: config.model,
        temperature: settings.defaultTemperature,
        maxTokens: settings.defaultMaxTokens,
        topP: settings.defaultTopP,
        frequencyPenalty: settings.defaultFrequencyPenalty,
        presencePenalty: settings.defaultPresencePenalty,
        stopSequences: settings.defaultStopSequences,
        timeout: settings.defaultTimeout,
        apiFormat: apiFormat,
        apiKey: apiKey,
      ),
  };
}
