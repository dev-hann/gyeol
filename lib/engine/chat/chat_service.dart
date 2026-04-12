import 'dart:convert';

import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/repositories/app_repository.dart';
import 'package:gyeol/engine/chat/tool_registry.dart';
import 'package:gyeol/providers/lllm_provider.dart';

const _systemPrompt =
    'You are Gyeol AI Assistant. You help users design '
    'and run AI processing pipelines.\n'
    '\n'
    'CONCEPTS:\n'
    '- Layer: A processing stage with typed inputs/outputs '
    'and assigned AI workers\n'
    '- Worker: An AI agent with a system prompt that processes '
    'tasks within a layer\n'
    '- Thread: An execution unit that processes files '
    'through ordered layers\n'
    '\n'
    'You can create, modify, and delete layers, workers, '
    'and threads. You can also run threads and check status.\n'
    '\n'
    'Respond in Korean when the user writes in Korean, '
    'and in English when they write in English.';

const _maxIterations = 5;

class ChatStreamTextEvent {
  const ChatStreamTextEvent(this.text);
  final String text;
}

class ChatStreamToolEvent {
  const ChatStreamToolEvent({required this.toolName, required this.content});
  final String toolName;
  final String content;
}

class ChatServiceResult {
  const ChatServiceResult({
    required this.assistantResponse,
    required this.newMessages,
  });
  final String assistantResponse;
  final List<ChatMessage> newMessages;
}

class ChatService {
  ChatService({required this.provider, required this.repo, this.onRunThread});

  final LlmProvider provider;
  final AppRepository repo;
  final Future<String> Function(String threadName)? onRunThread;

  Future<ChatServiceResult> handleMessage(
    String userMessage,
    List<ChatMessage> conversationHistory,
  ) async {
    final convId = conversationHistory.isNotEmpty
        ? conversationHistory.first.conversationId
        : '';

    final newMessages = <ChatMessage>[
      ChatMessage.create(
        conversationId: convId,
        role: 'user',
        content: userMessage,
      ),
    ];

    final apiMessages = _buildApiMessages(userMessage, conversationHistory);

    for (var i = 0; i < _maxIterations; i++) {
      final response = await provider.generateChat(
        messages: apiMessages,
        tools: ToolRegistry.getAllTools(),
      );

      final hasToolCalls =
          response.toolCalls != null && response.toolCalls!.isNotEmpty;

      if (!hasToolCalls) {
        final content = response.content ?? '';
        newMessages.add(
          ChatMessage.create(
            conversationId: convId,
            role: 'assistant',
            content: content,
          ),
        );
        return ChatServiceResult(
          assistantResponse: content,
          newMessages: newMessages,
        );
      }

      apiMessages.add(
        ChatMessageForApi(
          role: 'assistant',
          content: response.content,
          toolCalls: response.toolCalls,
        ),
      );

      for (final call in response.toolCalls!) {
        Map<String, dynamic> args;
        try {
          args = jsonDecode(call.arguments) as Map<String, dynamic>;
        } on Object {
          args = {};
        }

        String result;
        try {
          if (call.name == 'run_thread' && onRunThread != null) {
            final threadName = args['name'] as String? ?? '';
            result = await onRunThread!(threadName);
          } else {
            result = await ToolRegistry.executeTool(call.name, args, repo);
          }
        } on Object catch (e) {
          result = 'Error: $e';
        }

        apiMessages.add(
          ChatMessageForApi(role: 'tool', content: result, toolCallId: call.id),
        );

        newMessages.add(
          ChatMessage.create(
            conversationId: convId,
            role: 'tool',
            content: result,
            toolName: call.name,
            toolCallId: call.id,
          ),
        );
      }
    }

    const maxMessage = '최대 반복 횟수에 도달했습니다.';
    newMessages.add(
      ChatMessage.create(
        conversationId: convId,
        role: 'assistant',
        content: maxMessage,
      ),
    );
    return ChatServiceResult(
      assistantResponse: maxMessage,
      newMessages: newMessages,
    );
  }

  Stream<Object> handleMessageStream(
    String userMessage,
    List<ChatMessage> conversationHistory,
  ) async* {
    final apiMessages = _buildApiMessages(userMessage, conversationHistory);
    final allTools = ToolRegistry.getAllTools();

    for (var i = 0; i < _maxIterations; i++) {
      final toolCallAccumulators = <int, _ToolCallAccum>{};
      final textBuffer = StringBuffer();

      await for (final delta in provider.generateChatStream(
        messages: apiMessages,
        tools: allTools,
      )) {
        if (delta.done) break;
        if (delta.content != null) {
          textBuffer.write(delta.content);
          yield ChatStreamTextEvent(delta.content!);
        }
        if (delta.toolCalls != null) {
          for (final tc in delta.toolCalls!) {
            final idx = tc.index ?? 0;
            toolCallAccumulators.putIfAbsent(idx, _ToolCallAccum.new);
            if (tc.id != null) toolCallAccumulators[idx]!.id = tc.id!;
            if (tc.name != null) toolCallAccumulators[idx]!.name = tc.name!;
            if (tc.arguments != null) {
              toolCallAccumulators[idx]!.arguments += tc.arguments!;
            }
          }
        }
      }

      if (toolCallAccumulators.isEmpty) return;

      final completeToolCalls = toolCallAccumulators.entries
          .where((e) => e.value.id.isNotEmpty && e.value.name.isNotEmpty)
          .map(
            (e) => ToolCall(
              id: e.value.id,
              name: e.value.name,
              arguments: e.value.arguments,
            ),
          )
          .toList();

      if (completeToolCalls.isEmpty) continue;

      apiMessages.add(
        ChatMessageForApi(
          role: 'assistant',
          content: textBuffer.isEmpty ? null : textBuffer.toString(),
          toolCalls: completeToolCalls,
        ),
      );

      for (final call in completeToolCalls) {
        Map<String, dynamic> args;
        try {
          args = jsonDecode(call.arguments) as Map<String, dynamic>;
        } on Object {
          args = {};
        }

        String result;
        try {
          if (call.name == 'run_thread' && onRunThread != null) {
            final threadName = args['name'] as String? ?? '';
            result = await onRunThread!(threadName);
          } else {
            result = await ToolRegistry.executeTool(call.name, args, repo);
          }
        } on Object catch (e) {
          result = 'Error: $e';
        }

        apiMessages.add(
          ChatMessageForApi(role: 'tool', content: result, toolCallId: call.id),
        );

        yield ChatStreamToolEvent(toolName: call.name, content: result);
      }
    }

    yield const ChatStreamTextEvent('최대 반복 횟수에 도달했습니다.');
  }

  static const _maxHistoryMessages = 30;

  List<ChatMessageForApi> _buildApiMessages(
    String userMessage,
    List<ChatMessage> history,
  ) {
    final trimmed = history.length > _maxHistoryMessages
        ? history.sublist(history.length - _maxHistoryMessages)
        : history;
    final filtered = <ChatMessage>[];
    for (var i = 0; i < trimmed.length; i++) {
      final m = trimmed[i];
      if (m.role == 'tool') continue;
      if (m.role == 'assistant' &&
          m.content.isEmpty &&
          i + 1 < trimmed.length &&
          trimmed[i + 1].role == 'tool') {
        continue;
      }
      filtered.add(m);
    }
    return [
      const ChatMessageForApi(role: 'system', content: _systemPrompt),
      ...filtered.map(
        (m) => ChatMessageForApi(role: m.role, content: m.content),
      ),
      ChatMessageForApi(role: 'user', content: userMessage),
    ];
  }
}

class _ToolCallAccum {
  String id = '';
  String name = '';
  String arguments = '';
}
