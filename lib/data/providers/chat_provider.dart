import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/providers/core_providers.dart';
import 'package:gyeol/data/providers/settings_provider.dart';
import 'package:gyeol/engine/chat/chat_service.dart';
import 'package:gyeol/providers/anthropic_provider.dart';
import 'package:gyeol/providers/custom_provider.dart';
import 'package:gyeol/providers/lllm_provider.dart';
import 'package:gyeol/providers/ollama_provider.dart';
import 'package:gyeol/providers/openai_provider.dart';

LlmProvider _createLlmProvider(ProviderSettings settings) {
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

final conversationsProvider =
    AsyncNotifierProvider<ConversationsNotifier, List<ChatConversation>>(
      ConversationsNotifier.new,
    );

class ConversationsNotifier extends AsyncNotifier<List<ChatConversation>> {
  StreamSubscription<List<ChatConversation>>? _sub;

  @override
  Future<List<ChatConversation>> build() async {
    final repo = ref.watch(repositoryProvider);
    await _sub?.cancel();
    _sub = repo.chat.watchConversations().listen(
      (data) => state = AsyncData(data),
    );
    ref.onDispose(() => _sub?.cancel());
    return repo.chat.listConversations();
  }

  Future<ChatConversation> createConversation(String title) async {
    final repo = ref.read(repositoryProvider);
    final conv = ChatConversation.create(title);
    await repo.chat.saveConversation(conv);
    return conv;
  }

  Future<void> deleteConversation(String id) async {
    final repo = ref.read(repositoryProvider);
    await repo.chat.deleteConversation(id);
  }

  Future<void> updateConversation(ChatConversation conv) async {
    final repo = ref.read(repositoryProvider);
    await repo.chat.saveConversation(conv);
  }

  Future<void> renameConversation(String id, String title) async {
    final repo = ref.read(repositoryProvider);
    await repo.chat.updateConversationTitle(id, title);
  }

  Future<void> clearConversationMessages(String conversationId) async {
    final repo = ref.read(repositoryProvider);
    await repo.chat.clearMessages(conversationId);
    ref.invalidate(chatMessagesProvider(conversationId));
  }
}

final chatMessagesProvider = FutureProvider.family<List<ChatMessage>, String>((
  ref,
  conversationId,
) async {
  final repo = ref.watch(repositoryProvider);
  return repo.chat.listMessages(conversationId);
});

final chatSendingProvider = StateProvider<bool>((ref) => false);

final selectedConversationIdProvider = StateProvider<String?>((ref) => null);

final chatServiceProvider = Provider<ChatService>((ref) {
  final settingsAsync = ref.watch(settingsProvider);
  final repo = ref.watch(repositoryProvider);
  final settings = settingsAsync.valueOrNull ?? const ProviderSettings();
  final provider = _createLlmProvider(settings);
  return ChatService(provider: provider, repo: repo);
});
