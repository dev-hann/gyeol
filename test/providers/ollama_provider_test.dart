import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/providers/lllm_provider.dart';
import 'package:gyeol/providers/ollama_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('OllamaProvider', () {
    test('generateWithSystem returns content on success', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), 'http://localhost:11434/api/chat');
        expect(request.headers['Content-Type'], 'application/json');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], 'llama3');
        expect(body['temperature'], 0.7);
        expect((body['options'] as Map<String, dynamic>)['num_predict'], 100);
        expect(body['stream'], false);

        final messages = body['messages'] as List;
        expect((messages[0] as Map<String, dynamic>)['role'], 'system');
        expect((messages[0] as Map<String, dynamic>)['content'], 'sys');
        expect((messages[1] as Map<String, dynamic>)['role'], 'user');
        expect((messages[1] as Map<String, dynamic>)['content'], 'hi');

        return http.Response(
          jsonEncode({
            'message': {'content': 'Hello from Ollama!'},
          }),
          200,
        );
      });

      final provider = OllamaProvider(
        baseUrl: 'http://localhost:11434',
        model: 'llama3',
        temperature: 0.7,
        maxTokens: 100,
        client: mockClient,
      );

      final result = await provider.generateWithSystem('sys', 'hi');
      expect(result, 'Hello from Ollama!');
    });

    test('generateWithSystem throws LlmError on non-200 status', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"error": "bad"}', 500);
      });

      final provider = OllamaProvider(
        baseUrl: 'http://localhost:11434',
        model: 'llama3',
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
        return http.Response(jsonEncode(<String, dynamic>{}), 200);
      });

      final provider = OllamaProvider(
        baseUrl: 'http://localhost:11434',
        model: 'llama3',
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
      'generate delegates to generateWithSystem with default system prompt',
      () async {
        final mockClient = MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final messages = body['messages'] as List;
          expect(
            (messages[0] as Map<String, dynamic>)['content'],
            'You are a helpful AI assistant.',
          );

          return http.Response(
            jsonEncode({
              'message': {'content': 'response'},
            }),
            200,
          );
        });

        final provider = OllamaProvider(
          baseUrl: 'http://localhost:11434',
          model: 'llama3',
          temperature: 0.5,
          maxTokens: 50,
          client: mockClient,
        );

        final result = await provider.generate('hello');
        expect(result, 'response');
      },
    );

    test('generateWithSystem strips trailing slash from baseUrl', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), 'http://localhost:11434/api/chat');

        return http.Response(
          jsonEncode({
            'message': {'content': 'ok'},
          }),
          200,
        );
      });

      final provider = OllamaProvider(
        baseUrl: 'http://localhost:11434/',
        model: 'llama3',
        temperature: 0.7,
        maxTokens: 100,
        client: mockClient,
      );

      final result = await provider.generateWithSystem('sys', 'hi');
      expect(result, 'ok');
    });

    test(
      'generateWithSystem throws LlmError with parse message on malformed JSON',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response('not valid json{{{', 200);
        });

        final provider = OllamaProvider(
          baseUrl: 'http://localhost:11434',
          model: 'llama3',
          temperature: 0.7,
          maxTokens: 100,
          client: mockClient,
        );

        expect(
          provider.generateWithSystem('sys', 'hi'),
          throwsA(
            isA<LlmError>().having(
              (e) => e.message,
              'message',
              contains('Failed to parse response'),
            ),
          ),
        );
      },
    );

    test(
      'generateWithSystem throws LlmError on unexpected type in response',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode({'message': 'not a map'}), 200);
        });

        final provider = OllamaProvider(
          baseUrl: 'http://localhost:11434',
          model: 'llama3',
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
      'generateWithSystem uses correct URL when baseUrl has no trailing slash',
      () async {
        final mockClient = MockClient((request) async {
          expect(request.url.toString(), 'http://host:1234/api/chat');

          return http.Response(
            jsonEncode({
              'message': {'content': 'done'},
            }),
            200,
          );
        });

        final provider = OllamaProvider(
          baseUrl: 'http://host:1234',
          model: 'mistral',
          temperature: 0.3,
          maxTokens: 200,
          client: mockClient,
        );

        final result = await provider.generateWithSystem('sys', 'hi');
        expect(result, 'done');
      },
    );
  });
}
