import 'dart:convert';
import 'package:gyeol/data/models/app_models.dart';
import 'package:http/http.dart' as http;

String resolveEndpoint(String baseUrl, String path) {
  final clean = baseUrl.replaceAll(RegExp(r'/$'), '');
  if (clean.endsWith(path)) return clean;
  if (RegExp(r'/v\d+$').hasMatch(clean) && path.startsWith('/v1/')) {
    return '$clean${path.substring(3)}';
  }
  return '$clean$path';
}

class ModelFetcher {
  static Future<List<String>> fetchModels({
    required ProviderType provider,
    String? apiKey,
    String? baseUrl,
    CustomApiFormat? apiFormat,
  }) {
    return switch (provider) {
      ProviderType.openAI => _fetchOpenAI(apiKey ?? ''),
      ProviderType.anthropic => _fetchAnthropic(),
      ProviderType.ollama => _fetchOllama(baseUrl ?? 'http://localhost:11434'),
      ProviderType.custom => _fetchCustom(
        baseUrl ?? '',
        apiKey ?? '',
        apiFormat ?? CustomApiFormat.openAICompatible,
      ),
    };
  }

  static Future<CustomApiFormat> detectProtocol(
    String baseUrl,
    String apiKey,
  ) async {
    final clean = baseUrl.replaceAll(RegExp(r'/$'), '');
    if (clean.isEmpty) return CustomApiFormat.openAICompatible;

    if (await _probeOpenAI(clean, apiKey)) {
      return CustomApiFormat.openAICompatible;
    }

    if (await _probeOllama(clean)) {
      return CustomApiFormat.ollamaCompatible;
    }

    if (await _probeAnthropic(clean, apiKey)) {
      return CustomApiFormat.anthropicCompatible;
    }

    return CustomApiFormat.openAICompatible;
  }

  static Future<bool> _probeOpenAI(String baseUrl, String apiKey) async {
    final headers = <String, String>{};
    if (apiKey.isNotEmpty) headers['Authorization'] = 'Bearer $apiKey';

    for (final suffix in const ['/models', '/v1/models']) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl$suffix'),
          headers: headers,
        );
        if (response.statusCode == 200) return true;
      } on Object {
        continue;
      }
    }
    return false;
  }

  static Future<bool> _probeOllama(String baseUrl) async {
    for (final suffix in const ['/api/tags', '/v1/api/tags']) {
      try {
        final response = await http.get(Uri.parse('$baseUrl$suffix'));
        if (response.statusCode == 200) return true;
      } on Object {
        continue;
      }
    }
    return false;
  }

  static Future<bool> _probeAnthropic(String baseUrl, String apiKey) async {
    try {
      final headers = <String, String>{'anthropic-version': '2023-06-01'};
      if (apiKey.isNotEmpty) headers['x-api-key'] = apiKey;
      final response = await http.post(
        Uri.parse('$baseUrl/v1/messages'),
        headers: headers,
        body: jsonEncode({
          'model': 'claude-3-haiku-20240307',
          'max_tokens': 1,
          'messages': [
            {'role': 'user', 'content': 'hi'},
          ],
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 400) {
        return true;
      }
    } on Object {
      return false;
    }
    return false;
  }

  static Future<List<String>> _fetchOpenAI(String apiKey) async {
    if (apiKey.isEmpty) return [];
    try {
      final response = await http.get(
        Uri.parse('https://api.openai.com/v1/models'),
        headers: {'Authorization': 'Bearer $apiKey'},
      );
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final models = data['data'] as List<dynamic>? ?? [];
      return models
          .map((m) => (m as Map<String, dynamic>)['id'] as String)
          .where((id) => !id.contains(':') || id.startsWith('ft:'))
          .toList()
        ..sort();
    } on Object {
      return [];
    }
  }

  static Future<List<String>> _fetchAnthropic() async {
    return const [
      'claude-sonnet-4-20250514',
      'claude-opus-4-20250514',
      'claude-3-7-sonnet-20250219',
      'claude-3-5-sonnet-20241022',
      'claude-3-5-haiku-20241022',
      'claude-3-opus-20240229',
      'claude-3-haiku-20240307',
    ];
  }

  static Future<List<String>> _fetchOllama(String baseUrl) async {
    try {
      final url = '${baseUrl.replaceAll(RegExp(r'/$'), '')}/api/tags';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final models = data['models'] as List<dynamic>? ?? [];
      return models
          .map((m) => (m as Map<String, dynamic>)['name'] as String)
          .toList()
        ..sort();
    } on Object {
      return [];
    }
  }

  static Future<List<String>> _fetchCustom(
    String baseUrl,
    String apiKey,
    CustomApiFormat apiFormat,
  ) async {
    final clean = baseUrl.replaceAll(RegExp(r'/$'), '');
    return switch (apiFormat) {
      CustomApiFormat.openAICompatible => _fetchCustomOpenAI(clean, apiKey),
      CustomApiFormat.ollamaCompatible => _fetchOllama(clean),
      CustomApiFormat.anthropicCompatible => _fetchAnthropic(),
    };
  }

  static Future<List<String>> _fetchCustomOpenAI(
    String baseUrl,
    String apiKey,
  ) async {
    final headers = <String, String>{};
    if (apiKey.isNotEmpty) headers['Authorization'] = 'Bearer $apiKey';

    for (final suffix in const ['/models', '/v1/models']) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl$suffix'),
          headers: headers,
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final models = data['data'] as List<dynamic>? ?? [];
          return models
              .map((m) => (m as Map<String, dynamic>)['id'] as String)
              .toList()
            ..sort();
        }
      } on Object {
        continue;
      }
    }
    return [];
  }
}
