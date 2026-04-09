import 'dart:convert';

import 'package:gyeol/providers/lllm_provider.dart';
import 'package:http/http.dart' as http;

class AnthropicProvider implements LlmProvider {
  AnthropicProvider({
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
    if (apiKey.isEmpty) throw LlmError('Anthropic API key not set');

    final body = jsonEncode({
      'model': model,
      'system': system,
      'messages': [
        {'role': 'user', 'content': user},
      ],
      'temperature': temperature,
      'max_tokens': maxTokens,
    });

    final response = await _client.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'Content-Type': 'application/json',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      throw LlmError('${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final contentList = data['content'] as List<dynamic>?;
    final firstBlock = contentList?.firstOrNull as Map<String, dynamic>?;
    final content = firstBlock?['text'] as String?;
    if (content == null) throw LlmError('No content in response');
    return content;
  }

  @override
  void close() => _client.close();
}
