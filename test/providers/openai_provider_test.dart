import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/providers/lllm_provider.dart';
import 'package:gyeol/providers/openai_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('OpenAIProvider', () {
    test('generateWithSystem throws LlmError when apiKey is empty', () {
      final provider = OpenAIProvider(
        apiKey: '',
        model: 'gpt-4o',
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
        expect(
          request.url.toString(),
          'https://api.openai.com/v1/chat/completions',
        );
        expect(request.headers['Authorization'], 'Bearer test-key');
        expect(request.headers['Content-Type'], 'application/json');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], 'gpt-4o');
        expect(body['temperature'], 0.7);
        expect(body['max_tokens'], 100);

        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'Hello from GPT!'},
              },
            ],
          }),
          200,
        );
      });

      final provider = OpenAIProvider(
        apiKey: 'test-key',
        model: 'gpt-4o',
        temperature: 0.7,
        maxTokens: 100,
        client: mockClient,
      );

      final result = await provider.generateWithSystem('sys', 'hi');
      expect(result, 'Hello from GPT!');
    });

    test('generateWithSystem throws LlmError on non-200 status', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"error": "bad"}', 401);
      });

      final provider = OpenAIProvider(
        apiKey: 'test-key',
        model: 'gpt-4o',
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
            'choices': <Map<String, dynamic>>[{}],
          }),
          200,
        );
      });

      final provider = OpenAIProvider(
        apiKey: 'test-key',
        model: 'gpt-4o',
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
          return http.Response(jsonEncode({'choices': 'not-a-list'}), 200);
        });

        final provider = OpenAIProvider(
          apiKey: 'test-key',
          model: 'gpt-4o',
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

    test('generateWithSystem throws LlmError on non-map JSON body', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode([1, 2, 3]), 200);
      });

      final provider = OpenAIProvider(
        apiKey: 'test-key',
        model: 'gpt-4o',
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
      'generateWithSystem throws LlmError when choices is empty list',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode({'choices': <dynamic>[]}), 200);
        });

        final provider = OpenAIProvider(
          apiKey: 'test-key',
          model: 'gpt-4o',
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
          final messages = body['messages'] as List;
          expect((messages[0] as Map<String, dynamic>)['role'], 'system');
          expect(
            (messages[0] as Map<String, dynamic>)['content'],
            'You are a helpful AI assistant.',
          );

          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': 'response'},
                },
              ],
            }),
            200,
          );
        });

        final provider = OpenAIProvider(
          apiKey: 'test-key',
          model: 'gpt-4o',
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
