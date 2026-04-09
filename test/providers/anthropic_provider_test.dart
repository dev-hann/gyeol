import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/providers/anthropic_provider.dart';
import 'package:gyeol/providers/lllm_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('AnthropicProvider', () {
    test('generateWithSystem throws LlmError when apiKey is empty', () {
      final provider = AnthropicProvider(
        apiKey: '',
        model: 'claude-3-sonnet',
        temperature: 0.7,
        maxTokens: 100,
      );

      expect(
        provider.generateWithSystem('system', 'user'),
        throwsA(isA<LlmError>()),
      );
    });

    test('generateWithSystem returns content on success', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), 'https://api.anthropic.com/v1/messages');
        expect(request.headers['x-api-key'], 'test-key');
        expect(request.headers['anthropic-version'], '2023-06-01');
        expect(request.headers['Content-Type'], 'application/json');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], 'claude-3-sonnet');
        expect(body['system'], 'sys');
        expect(body['temperature'], 0.7);
        expect(body['max_tokens'], 100);

        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': 'Hello from Claude!'},
            ],
          }),
          200,
        );
      });

      final provider = AnthropicProvider(
        apiKey: 'test-key',
        model: 'claude-3-sonnet',
        temperature: 0.7,
        maxTokens: 100,
        client: mockClient,
      );

      final result = await provider.generateWithSystem('sys', 'hi');
      expect(result, 'Hello from Claude!');
    });

    test('generateWithSystem throws LlmError on non-200 status', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"error": "unauthorized"}', 401);
      });

      final provider = AnthropicProvider(
        apiKey: 'test-key',
        model: 'claude-3-sonnet',
        temperature: 0.7,
        maxTokens: 100,
        client: mockClient,
      );

      expect(
        provider.generateWithSystem('sys', 'hi'),
        throwsA(isA<LlmError>()),
      );
    });

    test('generateWithSystem throws LlmError when content is null', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'content': <Map<String, dynamic>>[{}],
          }),
          200,
        );
      });

      final provider = AnthropicProvider(
        apiKey: 'test-key',
        model: 'claude-3-sonnet',
        temperature: 0.7,
        maxTokens: 100,
        client: mockClient,
      );

      expect(
        provider.generateWithSystem('sys', 'hi'),
        throwsA(isA<LlmError>()),
      );
    });

    test(
      'generateWithSystem throws LlmError on malformed JSON response',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response('not valid json', 200);
        });

        final provider = AnthropicProvider(
          apiKey: 'test-key',
          model: 'claude-3-sonnet',
          temperature: 0.7,
          maxTokens: 100,
          client: mockClient,
        );

        expect(
          provider.generateWithSystem('sys', 'hi'),
          throwsA(isA<LlmError>()),
        );
      },
    );

    test(
      'generateWithSystem throws LlmError on wrong type in response',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode({'content': 'not-a-list'}), 200);
        });

        final provider = AnthropicProvider(
          apiKey: 'test-key',
          model: 'claude-3-sonnet',
          temperature: 0.7,
          maxTokens: 100,
          client: mockClient,
        );

        expect(
          provider.generateWithSystem('sys', 'hi'),
          throwsA(isA<LlmError>()),
        );
      },
    );

    test(
      'generate delegates to generateWithSystem with default system prompt',
      () async {
        final mockClient = MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['system'], 'You are a helpful AI assistant.');

          return http.Response(
            jsonEncode({
              'content': [
                {'type': 'text', 'text': 'response'},
              ],
            }),
            200,
          );
        });

        final provider = AnthropicProvider(
          apiKey: 'test-key',
          model: 'claude-3-sonnet',
          temperature: 0.5,
          maxTokens: 50,
          client: mockClient,
        );

        final result = await provider.generate('hello');
        expect(result, 'response');
      },
    );
  });
}
