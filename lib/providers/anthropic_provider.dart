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

  (String?, List<Map<String, dynamic>>) _prepareApiMessages(
    List<ChatMessageForApi> messages,
  ) {
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

    final rawMessages = <Map<String, dynamic>>[];
    var i = 0;
    while (i < filteredMessages.length) {
      final m = filteredMessages[i];
      if (m.role == 'user' && m.toolCallId != null) {
        final results = <Map<String, dynamic>>[
          {
            'type': 'tool_result',
            'tool_use_id': m.toolCallId,
            'content': m.content ?? '',
          },
        ];
        while (i + 1 < filteredMessages.length &&
            filteredMessages[i + 1].role == 'user' &&
            filteredMessages[i + 1].toolCallId != null) {
          i++;
          final next = filteredMessages[i];
          results.add({
            'type': 'tool_result',
            'tool_use_id': next.toolCallId,
            'content': next.content ?? '',
          });
        }
        rawMessages.add({'role': 'user', 'content': results});
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
        rawMessages.add({'role': 'assistant', 'content': contentList});
      } else {
        final map = <String, dynamic>{'role': m.role};
        map['content'] = m.content ?? '';
        rawMessages.add(map);
      }
      i++;
    }

    final apiMessages = <Map<String, dynamic>>[];
    for (final msg in rawMessages) {
      if (apiMessages.isNotEmpty &&
          apiMessages.last['role'] == msg['role'] &&
          apiMessages.last['content'] is String &&
          msg['content'] is String) {
        apiMessages.last['content'] =
            '${apiMessages.last['content']}\n${msg['content']}';
      } else {
        apiMessages.add(msg);
      }
    }

    return (systemPrompt, apiMessages);
  }

  @override
  Future<ChatResponse> generateChat({
    required List<ChatMessageForApi> messages,
    List<ToolDefinition>? tools,
  }) async {
    if (apiKey.isEmpty) throw LlmError('Anthropic API key not set');

    final (systemPrompt, apiMessages) = _prepareApiMessages(messages);

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

    final (systemPrompt, apiMessages) = _prepareApiMessages(messages);

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
          final raw = jsonDecode(data);
          if (raw is! Map<String, dynamic>) continue;
          final type = raw['type'] is String ? raw['type'] as String : null;
          if (type == 'message_stop') {
            yield const ChatStreamDelta(done: true);
            return;
          }
          if (type == 'content_block_start') {
            final contentBlock = raw['content_block'];
            if (contentBlock is Map<String, dynamic> &&
                contentBlock['type'] == 'tool_use') {
              yield ChatStreamDelta(
                toolCalls: [
                  ToolCallDelta(
                    index: raw['index'] is int ? raw['index'] as int : null,
                    id: contentBlock['id'] is String
                        ? contentBlock['id'] as String
                        : null,
                    name: contentBlock['name'] is String
                        ? contentBlock['name'] as String
                        : null,
                  ),
                ],
              );
            }
          }
          if (type == 'content_block_delta') {
            final delta = raw['delta'];
            if (delta is! Map<String, dynamic>) continue;
            final deltaType = delta['type'] is String
                ? delta['type'] as String
                : null;
            if (deltaType == 'text_delta') {
              final text = delta['text'];
              if (text is String) yield ChatStreamDelta(content: text);
            } else if (deltaType == 'input_json_delta') {
              final partialJson = delta['partial_json'];
              if (partialJson is String) {
                yield ChatStreamDelta(
                  toolCalls: [
                    ToolCallDelta(
                      index: raw['index'] is int ? raw['index'] as int : null,
                      arguments: partialJson,
                    ),
                  ],
                );
              }
            }
          }
        } on Object {
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
