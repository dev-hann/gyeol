import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/providers/core_providers.dart';
import 'package:gyeol/data/providers/logs_provider.dart';
import 'package:gyeol/data/providers/scheduler_run_provider.dart';
import 'package:gyeol/data/providers/settings_provider.dart';
import 'package:gyeol/data/providers/tasks_provider.dart';
import 'package:gyeol/engine/chat/chat_service.dart';
import 'package:gyeol/providers/provider_factory.dart';

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
      onError: (Object e, StackTrace st) {
        state = AsyncError(e, st);
      },
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
  final provider = createLlmProvider(settings);
  return ChatService(
    provider: provider,
    repo: repo,
    onRunThread: (threadName) async {
      final scheduler = ref.read(schedulerProvider);
      final thread = await repo.threads.getThread(threadName);
      if (thread == null) {
        return jsonEncode({'error': 'Thread "$threadName" not found'});
      }
      try {
        final results = await scheduler.runThread(thread);
        ref
          ..invalidate(tasksProvider)
          ..invalidate(queueSizeProvider)
          ..invalidate(logsProvider);
        return jsonEncode({
          'success': true,
          'thread': threadName,
          'results': results
              .map(
                (r) => <String, dynamic>{
                  'success': r.success,
                  'error': r.error,
                  'outputTasks': r.outputTasks.length,
                },
              )
              .toList(),
        });
      } on Object catch (e) {
        return jsonEncode({
          'success': false,
          'error': 'Thread execution failed: $e',
        });
      }
    },
  );
});
