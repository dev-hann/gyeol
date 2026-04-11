import 'dart:async';
import 'dart:convert';

import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/providers/lllm_provider.dart';
import 'package:gyeol/providers/model_fetcher.dart';
import 'package:http/http.dart' as http;

class CustomProvider implements LlmProvider {
  CustomProvider({
    required this.baseUrl,
    required this.model,
    required this.temperature,
    required this.maxTokens,
    required this.apiFormat,
    this.apiKey = '',
    this.topP = 1.0,
    this.frequencyPenalty = 0.0,
    this.presencePenalty = 0.0,
    this.stopSequences = const [],
    this.timeout = 60000,
    http.Client? client,
  }) : _client = client ?? http.Client();
  final String baseUrl;
  final String model;
  final double temperature;
  final int maxTokens;
  final CustomApiFormat apiFormat;
  final String apiKey;
  final double topP;
  final double frequencyPenalty;
  final double presencePenalty;
  final List<String> stopSequences;
  final int timeout;
  final http.Client _client;

  @override
  Future<String> generate(String prompt) {
    return generateWithSystem('You are a helpful AI assistant.', prompt);
  }

  @override
  Future<String> generateWithSystem(String system, String user) async {
    return switch (apiFormat) {
      CustomApiFormat.openAICompatible => _generateOpenAI(system, user),
      CustomApiFormat.anthropicCompatible => _generateAnthropic(system, user),
      CustomApiFormat.ollamaCompatible => _generateOllama(system, user),
    };
  }

  Future<String> _generateOpenAI(String system, String user) async {
    final url = resolveEndpoint(baseUrl, '/v1/chat/completions');

    final body = jsonEncode({
      'model': model,
      'messages': [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': user},
      ],
      'temperature': temperature,
      'max_tokens': maxTokens,
      'top_p': topP,
      'frequency_penalty': frequencyPenalty,
      'presence_penalty': presencePenalty,
      if (stopSequences.isNotEmpty) 'stop': stopSequences,
    });

    final headers = <String, String>{'Content-Type': 'application/json'};
    if (apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiKey';
    }

    final response = await _client
        .post(Uri.parse(url), headers: headers, body: body)
        .timeout(Duration(milliseconds: timeout));

    if (response.statusCode != 200) {
      throw LlmError('${response.statusCode}: ${response.body}');
    }

    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>?;
      final message = (choices != null && choices.isNotEmpty)
          ? (choices[0] as Map<String, dynamic>)['message']
                as Map<String, dynamic>?
          : null;
      final content = message?['content'] as String?;
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

  Future<String> _generateAnthropic(String system, String user) async {
    final url = resolveEndpoint(baseUrl, '/v1/messages');

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

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'anthropic-version': '2023-06-01',
    };
    if (apiKey.isNotEmpty) {
      headers['x-api-key'] = apiKey;
    }

    final response = await _client
        .post(Uri.parse(url), headers: headers, body: body)
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

  Future<String> _generateOllama(String system, String user) async {
    final url = resolveEndpoint(baseUrl, '/api/chat');

    final body = jsonEncode({
      'model': model,
      'messages': [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': user},
      ],
      'temperature': temperature,
      'options': {'num_predict': maxTokens, 'top_p': topP},
      'stream': false,
    });

    final response = await _client
        .post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(Duration(milliseconds: timeout));

    if (response.statusCode != 200) {
      throw LlmError('${response.statusCode}: ${response.body}');
    }

    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final message = data['message'] as Map<String, dynamic>?;
      final content = message?['content'] as String?;
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
    return switch (apiFormat) {
      CustomApiFormat.openAICompatible => _generateChatOpenAI(messages, tools),
      CustomApiFormat.anthropicCompatible => _generateChatAnthropic(
        messages,
        tools,
      ),
      CustomApiFormat.ollamaCompatible => _generateChatOpenAI(messages, tools),
    };
  }

  Future<ChatResponse> _generateChatOpenAI(
    List<ChatMessageForApi> messages,
    List<ToolDefinition>? tools,
  ) async {
    final url = resolveEndpoint(baseUrl, '/v1/chat/completions');

    final messagesList = messages.map((m) {
      final map = <String, dynamic>{'role': m.role};
      if (m.content != null) map['content'] = m.content;
      if (m.toolCalls != null) {
        map['tool_calls'] = m.toolCalls!
            .map(
              (tc) => {
                'id': tc.id,
                'type': 'function',
                'function': {'name': tc.name, 'arguments': tc.arguments},
              },
            )
            .toList();
      }
      if (m.toolCallId != null) map['tool_call_id'] = m.toolCallId;
      return map;
    }).toList();

    final bodyMap = <String, dynamic>{
      'model': model,
      'messages': messagesList,
      'temperature': temperature,
      'max_tokens': maxTokens,
      'top_p': topP,
      'frequency_penalty': frequencyPenalty,
      'presence_penalty': presencePenalty,
      if (stopSequences.isNotEmpty) 'stop': stopSequences,
    };

    if (tools != null && tools.isNotEmpty) {
      bodyMap['tools'] = tools
          .map(
            (t) => {
              'type': 'function',
              'function': {
                'name': t.name,
                'description': t.description,
                'parameters': t.parameters,
              },
            },
          )
          .toList();
      bodyMap['tool_choice'] = 'auto';
    }

    final headers = <String, String>{'Content-Type': 'application/json'};
    if (apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiKey';
    }

    final response = await _client
        .post(Uri.parse(url), headers: headers, body: jsonEncode(bodyMap))
        .timeout(Duration(milliseconds: timeout));

    if (response.statusCode != 200) {
      throw LlmError('${response.statusCode}: ${response.body}');
    }

    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>?;
      final message = (choices != null && choices.isNotEmpty)
          ? (choices[0] as Map<String, dynamic>)['message']
                as Map<String, dynamic>?
          : null;
      final content = message?['content'] as String?;
      final rawToolCalls = message?['tool_calls'] as List<dynamic>?;
      final parsedToolCalls = rawToolCalls?.map((tc) {
        final map = tc as Map<String, dynamic>;
        final fn = map['function'] as Map<String, dynamic>;
        return ToolCall(
          id: map['id'] as String,
          name: fn['name'] as String,
          arguments: fn['arguments'] as String,
        );
      }).toList();
      return ChatResponse(content: content, toolCalls: parsedToolCalls);
    } on LlmError {
      rethrow;
    } on FormatException catch (e) {
      throw LlmError('Failed to parse response: $e');
    } on Object catch (e) {
      throw LlmError('Failed to parse response: $e');
    }
  }

  Future<ChatResponse> _generateChatAnthropic(
    List<ChatMessageForApi> messages,
    List<ToolDefinition>? tools,
  ) async {
    final url = resolveEndpoint(baseUrl, '/v1/messages');

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

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'anthropic-version': '2023-06-01',
    };
    if (apiKey.isNotEmpty) {
      headers['x-api-key'] = apiKey;
    }

    final response = await _client
        .post(Uri.parse(url), headers: headers, body: jsonEncode(bodyMap))
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
  }) {
    return switch (apiFormat) {
      CustomApiFormat.openAICompatible => _streamOpenAI(messages, tools),
      CustomApiFormat.anthropicCompatible => _streamAnthropic(messages, tools),
      CustomApiFormat.ollamaCompatible => _streamOpenAI(messages, tools),
    };
  }

  Stream<ChatStreamDelta> _streamOpenAI(
    List<ChatMessageForApi> messages,
    List<ToolDefinition>? tools,
  ) async* {
    final url = resolveEndpoint(baseUrl, '/v1/chat/completions');

    final messagesList = messages.map((m) {
      final map = <String, dynamic>{'role': m.role};
      if (m.content != null) map['content'] = m.content;
      return map;
    }).toList();

    final bodyMap = <String, dynamic>{
      'model': model,
      'messages': messagesList,
      'temperature': temperature,
      'max_tokens': maxTokens,
      'top_p': topP,
      'frequency_penalty': frequencyPenalty,
      'presence_penalty': presencePenalty,
      if (stopSequences.isNotEmpty) 'stop': stopSequences,
      'stream': true,
    };

    if (tools != null && tools.isNotEmpty) {
      bodyMap['tools'] = tools
          .map(
            (t) => {
              'type': 'function',
              'function': {
                'name': t.name,
                'description': t.description,
                'parameters': t.parameters,
              },
            },
          )
          .toList();
      bodyMap['tool_choice'] = 'auto';
    }

    final body = jsonEncode(bodyMap);

    final headers = <String, String>{'Content-Type': 'application/json'};
    if (apiKey.isNotEmpty) headers['Authorization'] = 'Bearer $apiKey';

    final request = http.Request('POST', Uri.parse(url))
      ..headers.addAll(headers)
      ..body = body;

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
        if (data == '[DONE]') {
          yield const ChatStreamDelta(done: true);
          return;
        }
        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final choices = json['choices'] as List<dynamic>?;
          if (choices == null || choices.isEmpty) continue;
          final delta =
              (choices[0] as Map<String, dynamic>)['delta']
                  as Map<String, dynamic>?;
          final content = delta?['content'] as String?;
          if (content != null) yield ChatStreamDelta(content: content);
          final rawToolCalls = delta?['tool_calls'] as List<dynamic>?;
          if (rawToolCalls != null) {
            yield ChatStreamDelta(
              toolCalls: rawToolCalls.map((tc) {
                final map = tc as Map<String, dynamic>;
                final fn = map['function'] as Map<String, dynamic>?;
                return ToolCallDelta(
                  index: map['index'] as int?,
                  id: map['id'] as String?,
                  name: fn?['name'] as String?,
                  arguments: fn?['arguments'] as String?,
                );
              }).toList(),
            );
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

  Stream<ChatStreamDelta> _streamAnthropic(
    List<ChatMessageForApi> messages,
    List<ToolDefinition>? tools,
  ) async* {
    final url = resolveEndpoint(baseUrl, '/v1/messages');

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

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'anthropic-version': '2023-06-01',
    };
    if (apiKey.isNotEmpty) headers['x-api-key'] = apiKey;

    final request = http.Request('POST', Uri.parse(url))
      ..headers.addAll(headers)
      ..body = jsonEncode(bodyMap);

    final response = await _client
        .send(request)
        .timeout(Duration(milliseconds: timeout));

    if (response.statusCode != 200) {
      final respBody = await response.stream.bytesToString();
      throw LlmError('${response.statusCode}: $respBody');
    }

    var buffer = '';
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      buffer += chunk;
      while (buffer.contains('\n')) {
        final idx = buffer.indexOf('\n');
        final line = buffer.substring(0, idx).trim();
        buffer = buffer.substring(idx + 1);
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
    }
    yield const ChatStreamDelta(done: true);
  }

  @override
  void close() => _client.close();
}
