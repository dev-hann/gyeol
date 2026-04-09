import 'dart:convert';

import 'package:gyeol/providers/lllm_provider.dart';
import 'package:http/http.dart' as http;

class OpenAIProvider implements LlmProvider {
  OpenAIProvider({
    required this.apiKey,
    required this.model,
    required this.temperature,
    required this.maxTokens,
    http.Client? client,
  }) : _client = client ?? http.Client();
  final String apiKey;
  final String model;
  final double temperature;
  final int maxTokens;
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
    });

    final response = await _client.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: body,
    );

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
  void close() => _client.close();
}
