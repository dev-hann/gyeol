import 'dart:convert';
import 'package:http/http.dart' as http;
import 'lllm_provider.dart';

class AnthropicProvider implements LlmProvider {
  final String apiKey;
  final String model;
  final double temperature;
  final int maxTokens;

  AnthropicProvider({
    required this.apiKey,
    required this.model,
    required this.temperature,
    required this.maxTokens,
  });

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

    final response = await http.post(
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
    final content = data['content']?[0]?['text'] as String?;
    if (content == null) throw LlmError('No content in response');
    return content;
  }
}
