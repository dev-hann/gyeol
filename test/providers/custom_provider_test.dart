import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/providers/custom_provider.dart';
import 'package:gyeol/providers/lllm_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('CustomProvider - OpenAI Compatible', () {
    test('generateWithSystem returns content on success', () async {
      final mockClient = MockClient((request) async {
        expect(
          request.url.toString(),
          'http://localhost:8080/v1/chat/completions',
        );
        expect(request.headers['Authorization'], 'Bearer test-key');
        expect(request.headers['Content-Type'], 'application/json');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], 'my-model');
        expect(body['temperature'], 0.7);
        expect(body['max_tokens'], 100);

        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'Hello from custom!'},
              },
            ],
          }),
          200,
        );
      });

      final provider = CustomProvider(
        baseUrl: 'http://localhost:8080',
        model: 'my-model',
        temperature: 0.7,
        maxTokens: 100,
        apiFormat: CustomApiFormat.openAICompatible,
        apiKey: 'test-key',
        client: mockClient,
      );

      final result = await provider.generateWithSystem('sys', 'hi');
      expect(result, 'Hello from custom!');
    });

    test('sends request without Authorization when apiKey is empty', () async {
      final mockClient = MockClient((request) async {
        expect(request.headers.containsKey('Authorization'), false);

        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'ok'},
              },
            ],
          }),
          200,
        );
      });

      final provider = CustomProvider(
        baseUrl: 'http://localhost:8080',
        model: 'my-model',
        temperature: 0.7,
        maxTokens: 100,
        apiFormat: CustomApiFormat.openAICompatible,
        client: mockClient,
      );

      final result = await provider.generateWithSystem('sys', 'hi');
      expect(result, 'ok');
    });

    test('strips trailing slash from baseUrl', () async {
      final mockClient = MockClient((request) async {
        expect(
          request.url.toString(),
          'http://localhost:8080/v1/chat/completions',
        );

        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'ok'},
              },
            ],
          }),
          200,
        );
      });

      final provider = CustomProvider(
        baseUrl: 'http://localhost:8080/',
        model: 'my-model',
        temperature: 0.7,
        maxTokens: 100,
        apiFormat: CustomApiFormat.openAICompatible,
        apiKey: 'key',
        client: mockClient,
      );

      await provider.generateWithSystem('sys', 'hi');
    });

    test('throws LlmError on non-200 status', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"error": "bad"}', 500);
      });

      final provider = CustomProvider(
        baseUrl: 'http://localhost:8080',
        model: 'my-model',
        temperature: 0.7,
        maxTokens: 100,
        apiFormat: CustomApiFormat.openAICompatible,
        apiKey: 'key',
        client: mockClient,
      );

      expect(
        provider.generateWithSystem('sys', 'hi'),
        throwsA(isA<LlmError>()),
      );
    });

    test('throws LlmError when content is null', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'choices': <Map<String, dynamic>>[{}],
          }),
          200,
        );
      });

      final provider = CustomProvider(
        baseUrl: 'http://localhost:8080',
        model: 'my-model',
        temperature: 0.7,
        maxTokens: 100,
        apiFormat: CustomApiFormat.openAICompatible,
        apiKey: 'key',
        client: mockClient,
      );

      expect(
        provider.generateWithSystem('sys', 'hi'),
        throwsA(isA<LlmError>()),
      );
    });
  });

  group('CustomProvider - Anthropic Compatible', () {
    test('generateWithSystem returns content on success', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), 'http://localhost:8080/v1/messages');
        expect(request.headers['x-api-key'], 'test-key');
        expect(request.headers['anthropic-version'], '2023-06-01');
        expect(request.headers['Content-Type'], 'application/json');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], 'my-model');
        expect(body['system'], 'sys');
        expect(body['temperature'], 0.7);
        expect(body['max_tokens'], 100);

        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': 'Hello from Anthropic custom!'},
            ],
          }),
          200,
        );
      });

      final provider = CustomProvider(
        baseUrl: 'http://localhost:8080',
        model: 'my-model',
        temperature: 0.7,
        maxTokens: 100,
        apiFormat: CustomApiFormat.anthropicCompatible,
        apiKey: 'test-key',
        client: mockClient,
      );

      final result = await provider.generateWithSystem('sys', 'hi');
      expect(result, 'Hello from Anthropic custom!');
    });

    test('sends request without x-api-key when apiKey is empty', () async {
      final mockClient = MockClient((request) async {
        expect(request.headers.containsKey('x-api-key'), false);

        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': 'ok'},
            ],
          }),
          200,
        );
      });

      final provider = CustomProvider(
        baseUrl: 'http://localhost:8080',
        model: 'my-model',
        temperature: 0.7,
        maxTokens: 100,
        apiFormat: CustomApiFormat.anthropicCompatible,
        client: mockClient,
      );

      final result = await provider.generateWithSystem('sys', 'hi');
      expect(result, 'ok');
    });

    test('throws LlmError when content is null', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'content': <Map<String, dynamic>>[]}),
          200,
        );
      });

      final provider = CustomProvider(
        baseUrl: 'http://localhost:8080',
        model: 'my-model',
        temperature: 0.7,
        maxTokens: 100,
        apiFormat: CustomApiFormat.anthropicCompatible,
        apiKey: 'key',
        client: mockClient,
      );

      expect(
        provider.generateWithSystem('sys', 'hi'),
        throwsA(isA<LlmError>()),
      );
    });
  });

  group('CustomProvider - Ollama Compatible', () {
    test('generateWithSystem returns content on success', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), 'http://localhost:8080/api/chat');
        expect(request.headers['Content-Type'], 'application/json');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], 'my-model');
        expect(body['temperature'], 0.7);
        expect(body['stream'], false);
        expect((body['options'] as Map<String, dynamic>)['num_predict'], 100);

        return http.Response(
          jsonEncode({
            'message': {'content': 'Hello from Ollama custom!'},
          }),
          200,
        );
      });

      final provider = CustomProvider(
        baseUrl: 'http://localhost:8080',
        model: 'my-model',
        temperature: 0.7,
        maxTokens: 100,
        apiFormat: CustomApiFormat.ollamaCompatible,
        client: mockClient,
      );

      final result = await provider.generateWithSystem('sys', 'hi');
      expect(result, 'Hello from Ollama custom!');
    });

    test('throws LlmError when content is null', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'message': <String, dynamic>{}}), 200);
      });

      final provider = CustomProvider(
        baseUrl: 'http://localhost:8080',
        model: 'my-model',
        temperature: 0.7,
        maxTokens: 100,
        apiFormat: CustomApiFormat.ollamaCompatible,
        client: mockClient,
      );

      expect(
        provider.generateWithSystem('sys', 'hi'),
        throwsA(isA<LlmError>()),
      );
    });
  });

  group('CustomProvider - generate', () {
    test(
      'delegates to generateWithSystem with default system prompt',
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
              'choices': [
                {
                  'message': {'content': 'response'},
                },
              ],
            }),
            200,
          );
        });

        final provider = CustomProvider(
          baseUrl: 'http://localhost:8080',
          model: 'my-model',
          temperature: 0.5,
          maxTokens: 50,
          apiFormat: CustomApiFormat.openAICompatible,
          apiKey: 'key',
          client: mockClient,
        );

        final result = await provider.generate('hello');
        expect(result, 'response');
      },
    );
  });

  group('CustomProvider - error handling', () {
    test(
      'OpenAI compatible throws LlmError with parse message on malformed JSON',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response('not valid json{{{', 200);
        });

        final provider = CustomProvider(
          baseUrl: 'http://localhost:8080',
          model: 'my-model',
          temperature: 0.7,
          maxTokens: 100,
          apiFormat: CustomApiFormat.openAICompatible,
          apiKey: 'key',
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

    test('Anthropic compatible throws LlmError on malformed JSON', () async {
      final mockClient = MockClient((request) async {
        return http.Response('not valid json{{{', 200);
      });

      final provider = CustomProvider(
        baseUrl: 'http://localhost:8080',
        model: 'my-model',
        temperature: 0.7,
        maxTokens: 100,
        apiFormat: CustomApiFormat.anthropicCompatible,
        apiKey: 'key',
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
    });

    test('Ollama compatible throws LlmError on malformed JSON', () async {
      final mockClient = MockClient((request) async {
        return http.Response('not valid json{{{', 200);
      });

      final provider = CustomProvider(
        baseUrl: 'http://localhost:8080',
        model: 'my-model',
        temperature: 0.7,
        maxTokens: 100,
        apiFormat: CustomApiFormat.ollamaCompatible,
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
    });

    test(
      'OpenAI compatible throws LlmError on unexpected type in response',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode({'choices': 'not a list'}), 200);
        });

        final provider = CustomProvider(
          baseUrl: 'http://localhost:8080',
          model: 'my-model',
          temperature: 0.7,
          maxTokens: 100,
          apiFormat: CustomApiFormat.openAICompatible,
          apiKey: 'key',
          client: mockClient,
        );

        expect(
          provider.generateWithSystem('sys', 'hi'),
          throwsA(isA<LlmError>()),
        );
      },
    );

    test(
      'Anthropic compatible throws LlmError on unexpected type in response',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode({'content': 'not a list'}), 200);
        });

        final provider = CustomProvider(
          baseUrl: 'http://localhost:8080',
          model: 'my-model',
          temperature: 0.7,
          maxTokens: 100,
          apiFormat: CustomApiFormat.anthropicCompatible,
          apiKey: 'key',
          client: mockClient,
        );

        expect(
          provider.generateWithSystem('sys', 'hi'),
          throwsA(isA<LlmError>()),
        );
      },
    );

    test(
      'Ollama compatible throws LlmError on unexpected type in response',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode({'message': 'not a map'}), 200);
        });

        final provider = CustomProvider(
          baseUrl: 'http://localhost:8080',
          model: 'my-model',
          temperature: 0.7,
          maxTokens: 100,
          apiFormat: CustomApiFormat.ollamaCompatible,
          client: mockClient,
        );

        expect(
          provider.generateWithSystem('sys', 'hi'),
          throwsA(isA<LlmError>()),
        );
      },
    );
  });
}
