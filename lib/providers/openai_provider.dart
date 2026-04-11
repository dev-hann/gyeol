import 'dart:async';
import 'dart:convert';

import 'package:gyeol/providers/lllm_provider.dart';
import 'package:http/http.dart' as http;

class OpenAIProvider implements LlmProvider {
  OpenAIProvider({
    required this.apiKey,
    required this.model,
    required this.temperature,
    required this.maxTokens,
    this.topP = 1.0,
    this.frequencyPenalty = 0.0,
    this.presencePenalty = 0.0,
    this.stopSequences = const [],
    this.timeout = 60000,
    http.Client? client,
  }) : _client = client ?? http.Client();
  final String apiKey;
  final String model;
  final double temperature;
  final int maxTokens;
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
    if (apiKey.isEmpty) throw LlmError('OpenAI API key not set');

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

    final response = await _client
        .post(
          Uri.parse('https://api.openai.com/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer $apiKey',
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

  @override
  Future<ChatResponse> generateChat({
    required List<ChatMessageForApi> messages,
    List<ToolDefinition>? tools,
  }) async {
    if (apiKey.isEmpty) throw LlmError('OpenAI API key not set');

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

    final response = await _client
        .post(
          Uri.parse('https://api.openai.com/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer $apiKey',
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

  @override
  Stream<ChatStreamDelta> generateChatStream({
    required List<ChatMessageForApi> messages,
    List<ToolDefinition>? tools,
  }) async* {
    if (apiKey.isEmpty) throw LlmError('OpenAI API key not set');

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

    final request =
        http.Request(
            'POST',
            Uri.parse('https://api.openai.com/v1/chat/completions'),
          )
          ..headers.addAll({
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          })
          ..body = body;

    final response = await _client
        .send(request)
        .timeout(Duration(milliseconds: timeout));

    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw LlmError('${response.statusCode}: $body');
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
          if (content != null) {
            yield ChatStreamDelta(content: content);
          }
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
    }
    yield const ChatStreamDelta(done: true);
  }

  @override
  void close() => _client.close();
}
