import 'dart:convert';

import 'package:gyeol/providers/lllm_provider.dart';
import 'package:http/http.dart' as http;

class OllamaProvider implements LlmProvider {
  OllamaProvider({
    required this.baseUrl,
    required this.model,
    required this.temperature,
    required this.maxTokens,
    http.Client? client,
  }) : _client = client ?? http.Client();
  final String baseUrl;
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
    final url = '${baseUrl.replaceAll(RegExp(r'/$'), '')}/api/chat';

    final body = jsonEncode({
      'model': model,
      'messages': [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': user},
      ],
      'temperature': temperature,
      'options': {'num_predict': maxTokens},
      'stream': false,
    });

    final response = await _client.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 200) {
      throw LlmError('${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final message = data['message'] as Map<String, dynamic>?;
    final content = message?['content'] as String?;
    if (content == null) throw LlmError('No content in response');
    return content;
  }
}
