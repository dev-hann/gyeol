import 'dart:async';
import 'dart:convert';

import 'package:gyeol/providers/lllm_provider.dart';
import 'package:http/http.dart' as http;

class AnthropicProvider implements LlmProvider {
  AnthropicProvider({
    required this.apiKey,
    required this.model,
    required this.temperature,
    required this.maxTokens,
    this.topP = 1.0,
    this.stopSequences = const [],
    this.timeout = 60000,
    http.Client? client,
  }) : _client = client ?? http.Client();
  final String apiKey;
  final String model;
  final double temperature;
  final int maxTokens;
  final double topP;
  final List<String> stopSequences;
  final int timeout;
  final http.Client _client;

  @override
  Future<String> generate(String prompt) {
    return generateWithSystem('You are a helpful AI assistant.', prompt);
  }

  @override
  Future<String> generateWithSystem(String system, String user) async {
    if (apiKey.isEmpty) throw LlmError('Anthropic API key not set');

    final body = jsonEncode({
      'model': model,
      'system': system,
      'messages': [
        {'role': 'user', 'content': user},
      ],
      'temperature': temperature,
      'max_tokens': maxTokens,
      'top_p': topP,
      if (stopSequences.isNotEmpty) 'stop_sequences': stopSequences,
    });

    final response = await _client
        .post(
          Uri.parse('https://api.anthropic.com/v1/messages'),
          headers: {
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
            'Content-Type': 'application/json',
          },
          body: body,
        )
        .timeout(Duration(milliseconds: timeout));

    if (response.statusCode != 200) {
      throw LlmError('${response.statusCode}: ${response.body}');
    }

    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final contentList = data['content'] as List<dynamic>?;
      final firstBlock = contentList?.firstOrNull as Map<String, dynamic>?;
      final content = firstBlock?['text'] as String?;
      if (content == null) throw LlmError('No content in response');
      return content;
    } on LlmError {
      rethrow;
    } on FormatException catch (e) {
      throw LlmError('Failed to parse response: $e');
    } on Object catch (e) {
      throw LlmError('Failed to parse response: $e');
    }
  }

  @override
  Future<ChatResponse> generateChat({
    required List<ChatMessageForApi> messages,
    List<ToolDefinition>? tools,
  }) async {
    if (apiKey.isEmpty) throw LlmError('Anthropic API key not set');

    String? systemPrompt;
    final filteredMessages = <ChatMessageForApi>[];
    for (final m in messages) {
      if (m.role == 'system') {
        systemPrompt = m.content;
      } else if (m.role == 'tool') {
        filteredMessages.add(
          ChatMessageForApi(
            role: 'user',
            content: m.content,
            toolCallId: m.toolCallId,
          ),
        );
      } else {
        filteredMessages.add(m);
      }
    }

    final apiMessages = <Map<String, dynamic>>[];
    for (final m in filteredMessages) {
      if (m.role == 'user' && m.toolCallId != null) {
        apiMessages.add({
          'role': 'user',
          'content': [
            {
              'type': 'tool_result',
              'tool_use_id': m.toolCallId,
              'content': m.content ?? '',
            },
          ],
        });
      } else if (m.role == 'assistant' && m.toolCalls != null) {
        final contentList = <Map<String, dynamic>>[];
        if (m.content != null) {
          contentList.add({'type': 'text', 'text': m.content});
        }
        for (final tc in m.toolCalls!) {
          Map<String, dynamic> input;
          try {
            input = jsonDecode(tc.arguments) as Map<String, dynamic>;
          } on Object {
            input = {};
          }
          contentList.add({
            'type': 'tool_use',
            'id': tc.id,
            'name': tc.name,
            'input': input,
          });
        }
        apiMessages.add({'role': 'assistant', 'content': contentList});
      } else {
        final map = <String, dynamic>{'role': m.role};
        map['content'] = m.content ?? '';
        apiMessages.add(map);
      }
    }

    final bodyMap = <String, dynamic>{
      'model': model,
      'messages': apiMessages,
      'temperature': temperature,
      'max_tokens': maxTokens,
      'top_p': topP,
      if (stopSequences.isNotEmpty) 'stop_sequences': stopSequences,
    };

    if (systemPrompt != null) {
      bodyMap['system'] = systemPrompt;
    }

    if (tools != null && tools.isNotEmpty) {
      bodyMap['tools'] = tools
          .map(
            (t) => {
              'name': t.name,
              'description': t.description,
              'input_schema': t.parameters,
            },
          )
          .toList();
      bodyMap['tool_choice'] = {'type': 'auto'};
    }

    final response = await _client
        .post(
          Uri.parse('https://api.anthropic.com/v1/messages'),
          headers: {
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(bodyMap),
        )
        .timeout(Duration(milliseconds: timeout));

    if (response.statusCode != 200) {
      throw LlmError('${response.statusCode}: ${response.body}');
    }

    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final contentList = data['content'] as List<dynamic>;
      String? textContent;
      final parsedToolCalls = <ToolCall>[];

      for (final block in contentList) {
        final blockMap = block as Map<String, dynamic>;
        if (blockMap['type'] == 'text') {
          textContent = blockMap['text'] as String?;
        } else if (blockMap['type'] == 'tool_use') {
          final input = blockMap['input'] as Map<String, dynamic>;
          parsedToolCalls.add(
            ToolCall(
              id: blockMap['id'] as String,
              name: blockMap['name'] as String,
              arguments: jsonEncode(input),
            ),
          );
        }
      }

      return ChatResponse(
        content: textContent,
        toolCalls: parsedToolCalls.isEmpty ? null : parsedToolCalls,
      );
    } on LlmError {
      rethrow;
    } on FormatException catch (e) {
      throw LlmError('Failed to parse response: $e');
    } on Object catch (e) {
      throw LlmError('Failed to parse response: $e');
    }
  }

  @override
  Stream<ChatStreamDelta> generateChatStream({
    required List<ChatMessageForApi> messages,
    List<ToolDefinition>? tools,
  }) async* {
    if (apiKey.isEmpty) throw LlmError('Anthropic API key not set');

    String? systemPrompt;
    final apiMessages = <Map<String, dynamic>>[];
    for (final m in messages) {
      if (m.role == 'system') {
        systemPrompt = m.content;
      } else {
        apiMessages.add({'role': m.role, 'content': m.content ?? ''});
      }
    }

    final bodyMap = <String, dynamic>{
      'model': model,
      'messages': apiMessages,
      'temperature': temperature,
      'max_tokens': maxTokens,
      'top_p': topP,
      if (stopSequences.isNotEmpty) 'stop_sequences': stopSequences,
      'stream': true,
    };
    if (systemPrompt != null) bodyMap['system'] = systemPrompt;

    if (tools != null && tools.isNotEmpty) {
      bodyMap['tools'] = tools
          .map(
            (t) => {
              'name': t.name,
              'description': t.description,
              'input_schema': t.parameters,
            },
          )
          .toList();
      bodyMap['tool_choice'] = {'type': 'auto'};
    }

    final request =
        http.Request('POST', Uri.parse('https://api.anthropic.com/v1/messages'))
          ..headers.addAll({
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
            'Content-Type': 'application/json',
          })
          ..body = jsonEncode(bodyMap);

    final response = await _client
        .send(request)
        .timeout(Duration(milliseconds: timeout));

    if (response.statusCode != 200) {
      final respBody = await response.stream.bytesToString();
      throw LlmError('${response.statusCode}: $respBody');
    }

    final buffer = StringBuffer();
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      buffer.write(chunk);
      var remaining = buffer.toString();
      while (remaining.contains('\n')) {
        final idx = remaining.indexOf('\n');
        final line = remaining.substring(0, idx).trim();
        remaining = remaining.substring(idx + 1);
        if (!line.startsWith('data: ')) continue;
        final data = line.substring(6).trim();
        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final type = json['type'] as String?;
          if (type == 'message_stop') {
            yield const ChatStreamDelta(done: true);
            return;
          }
          if (type == 'content_block_start') {
            final contentBlock = json['content_block'] as Map<String, dynamic>?;
            if (contentBlock?['type'] == 'tool_use') {
              yield ChatStreamDelta(
                toolCalls: [
                  ToolCallDelta(
                    index: json['index'] as int?,
                    id: contentBlock?['id'] as String?,
                    name: contentBlock?['name'] as String?,
                  ),
                ],
              );
            }
          }
          if (type == 'content_block_delta') {
            final delta = json['delta'] as Map<String, dynamic>?;
            final deltaType = delta?['type'] as String?;
            if (deltaType == 'text_delta') {
              final text = delta?['text'] as String?;
              if (text != null) yield ChatStreamDelta(content: text);
            } else if (deltaType == 'input_json_delta') {
              final partialJson = delta?['partial_json'] as String?;
              if (partialJson != null) {
                yield ChatStreamDelta(
                  toolCalls: [
                    ToolCallDelta(
                      index: json['index'] as int?,
                      arguments: partialJson,
                    ),
                  ],
                );
              }
            }
          }
        } on FormatException {
          continue;
        }
      }
      buffer
        ..clear()
        ..write(remaining);
    }
    yield const ChatStreamDelta(done: true);
  }

  @override
  void close() => _client.close();
}
