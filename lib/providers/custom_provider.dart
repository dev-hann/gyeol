import 'dart:convert';

import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/providers/lllm_provider.dart';
import 'package:http/http.dart' as http;

class CustomProvider implements LlmProvider {
  CustomProvider({
    required this.baseUrl,
    required this.model,
    required this.temperature,
    required this.maxTokens,
    required this.apiFormat,
    this.apiKey = '',
    http.Client? client,
  }) : _client = client ?? http.Client();
  final String baseUrl;
  final String model;
  final double temperature;
  final int maxTokens;
  final CustomApiFormat apiFormat;
  final String apiKey;
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
    final url = '${baseUrl.replaceAll(RegExp(r'/$'), '')}/v1/chat/completions';

    final body = jsonEncode({
      'model': model,
      'messages': [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': user},
      ],
      'temperature': temperature,
      'max_tokens': maxTokens,
    });

    final headers = <String, String>{'Content-Type': 'application/json'};
    if (apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiKey';
    }

    final response = await _client.post(
      Uri.parse(url),
      headers: headers,
      body: body,
    );

    if (response.statusCode != 200) {
      throw LlmError('${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>?;
    final message = (choices != null && choices.isNotEmpty)
        ? (choices[0] as Map<String, dynamic>)['message']
              as Map<String, dynamic>?
        : null;
    final content = message?['content'] as String?;
    if (content == null) throw LlmError('No content in response');
    return content;
  }

  Future<String> _generateAnthropic(String system, String user) async {
    final url = '${baseUrl.replaceAll(RegExp(r'/$'), '')}/v1/messages';

    final body = jsonEncode({
      'model': model,
      'system': system,
      'messages': [
        {'role': 'user', 'content': user},
      ],
      'temperature': temperature,
      'max_tokens': maxTokens,
    });

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'anthropic-version': '2023-06-01',
    };
    if (apiKey.isNotEmpty) {
      headers['x-api-key'] = apiKey;
    }

    final response = await _client.post(
      Uri.parse(url),
      headers: headers,
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

  Future<String> _generateOllama(String system, String user) async {
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

  @override
  void close() => _client.close();
}
