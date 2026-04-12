import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/providers/custom_provider.dart';
import 'package:gyeol/providers/lllm_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

List<int> _enc(String s) => utf8.encode(s);

class _StreamClient extends http.BaseClient {
  _StreamClient(this._handler);
  final Future<http.StreamedResponse> Function() _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => _handler();
}

class _StreamClientWithRequest extends http.BaseClient {
  _StreamClientWithRequest(this._handler);
  final Future<http.StreamedResponse> Function(http.BaseRequest) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _handler(request);
}

const _hiMsg = [ChatMessageForApi(role: 'user', content: 'hi')];

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

  group('CustomProvider - OpenAI Compatible - generateChatStream', () {
    test('yields content deltas from SSE stream', () async {
      final sseData = [
        'data: ${jsonEncode({
          'choices': [
            {
              'delta': {'content': 'Hello'},
            },
          ],
        })}',
        'data: ${jsonEncode({
          'choices': [
            {
              'delta': {'content': ' World'},
            },
          ],
        })}',
        'data: [DONE]',
        '',
      ].join('\n');

      final client = _StreamClient(() async {
        return http.StreamedResponse(Stream.value(_enc(sseData)), 200);
      });

      final provider = CustomProvider(
        baseUrl: 'http://localhost:8080',
        model: 'my-model',
        temperature: 0.7,
        maxTokens: 100,
        apiFormat: CustomApiFormat.openAICompatible,
        apiKey: 'test-key',
        client: client,
      );

      final deltas = await provider
          .generateChatStream(messages: _hiMsg)
          .toList();

      expect(deltas.length, 3);
      expect(deltas[0].content, 'Hello');
      expect(deltas[1].content, ' World');
      expect(deltas[2].done, true);
    });

    test('yields tool call deltas from SSE stream', () async {
      final tc1 = {
        'index': 0,
        'id': 'call_1',
        'function': {'name': 'get_weather', 'arguments': '{"city":'},
      };
      final tc2 = {
        'index': 0,
        'function': {'arguments': '"Seoul"}'},
      };
      final sseData = [
        'data: ${jsonEncode({
          'choices': [
            {
              'delta': {
                'tool_calls': [tc1],
              },
            },
          ],
        })}',
        'data: ${jsonEncode({
          'choices': [
            {
              'delta': {
                'tool_calls': [tc2],
              },
            },
          ],
        })}',
        'data: [DONE]',
        '',
      ].join('\n');

      final client = _StreamClient(() async {
        return http.StreamedResponse(Stream.value(_enc(sseData)), 200);
      });

      final provider = CustomProvider(
        baseUrl: 'http://localhost:8080',
        model: 'my-model',
        temperature: 0.7,
        maxTokens: 100,
        apiFormat: CustomApiFormat.openAICompatible,
        apiKey: 'key',
        client: client,
      );

      final deltas = await provider
          .generateChatStream(messages: _hiMsg)
          .toList();

      expect(deltas.length, 3);
      expect(deltas[0].toolCalls, isNotNull);
      expect(deltas[0].toolCalls!.length, 1);
      expect(deltas[0].toolCalls![0].id, 'call_1');
      expect(deltas[0].toolCalls![0].name, 'get_weather');
      expect(deltas[0].toolCalls![0].arguments, '{"city":');
      expect(deltas[1].toolCalls![0].arguments, '"Seoul"}');
      expect(deltas[2].done, true);
    });

    test('throws LlmError on non-200 status', () async {
      final client = _StreamClient(() async {
        return http.StreamedResponse(Stream.value(_enc('error body')), 500);
      });

      final provider = CustomProvider(
        baseUrl: 'http://localhost:8080',
        model: 'my-model',
        temperature: 0.7,
        maxTokens: 100,
        apiFormat: CustomApiFormat.openAICompatible,
        apiKey: 'key',
        client: client,
      );

      expect(
        provider.generateChatStream(messages: _hiMsg).toList(),
        throwsA(isA<LlmError>()),
      );
    });

    test('yields done when stream ends without [DONE] marker', () async {
      final sseData = [
        'data: ${jsonEncode({
          'choices': [
            {
              'delta': {'content': 'partial'},
            },
          ],
        })}',
        '',
      ].join('\n');

      final client = _StreamClient(() async {
        return http.StreamedResponse(Stream.value(_enc(sseData)), 200);
      });

      final provider = CustomProvider(
        baseUrl: 'http://localhost:8080',
        model: 'my-model',
        temperature: 0.7,
        maxTokens: 100,
        apiFormat: CustomApiFormat.openAICompatible,
        apiKey: 'key',
        client: client,
      );

      final deltas = await provider
          .generateChatStream(messages: _hiMsg)
          .toList();

      expect(deltas.length, 2);
      expect(deltas[0].content, 'partial');
      expect(deltas[1].done, true);
    });

    test('sends Authorization and stream:true in request', () async {
      final client = _StreamClientWithRequest((request) async {
        expect(request.headers['Authorization'], 'Bearer my-key');
        final body =
            jsonDecode((request as http.Request).body) as Map<String, dynamic>;
        expect(body['stream'], true);
        return http.StreamedResponse(Stream.value(_enc('data: [DONE]\n')), 200);
      });

      final provider = CustomProvider(
        baseUrl: 'http://localhost:8080',
        model: 'my-model',
        temperature: 0.7,
        maxTokens: 100,
        apiFormat: CustomApiFormat.openAICompatible,
        apiKey: 'my-key',
        client: client,
      );

      await provider.generateChatStream(messages: _hiMsg).toList();
    });
  });

  group('CustomProvider - Anthropic Compatible - generateChatStream', () {
    test('yields content deltas from SSE stream', () async {
      final sseData = [
        'event: content_block_delta',
        'data: ${jsonEncode({
          'type': 'content_block_delta',
          'index': 0,
          'delta': {'type': 'text_delta', 'text': 'Hello'},
        })}',
        'event: content_block_delta',
        'data: ${jsonEncode({
          'type': 'content_block_delta',
          'index': 0,
          'delta': {'type': 'text_delta', 'text': ' World'},
        })}',
        'event: message_stop',
        'data: ${jsonEncode({'type': 'message_stop'})}',
        '',
      ].join('\n');

      final client = _StreamClient(() async {
        return http.StreamedResponse(Stream.value(_enc(sseData)), 200);
      });

      final provider = CustomProvider(
        baseUrl: 'http://localhost:8080',
        model: 'my-model',
        temperature: 0.7,
        maxTokens: 100,
        apiFormat: CustomApiFormat.anthropicCompatible,
        apiKey: 'test-key',
        client: client,
      );

      final deltas = await provider
          .generateChatStream(messages: _hiMsg)
          .toList();

      expect(deltas.length, 3);
      expect(deltas[0].content, 'Hello');
      expect(deltas[1].content, ' World');
      expect(deltas[2].done, true);
    });

    test('yields tool call deltas from SSE stream', () async {
      final blockStart = {
        'type': 'content_block_start',
        'index': 1,
        'content_block': {
          'type': 'tool_use',
          'id': 'tool_1',
          'name': 'get_weather',
        },
      };
      final blockDelta = {
        'type': 'content_block_delta',
        'index': 1,
        'delta': {
          'type': 'input_json_delta',
          'partial_json': '{"city": "Seoul"}',
        },
      };
      final msgStop = {'type': 'message_stop'};
      final sseData = [
        'event: content_block_start',
        'data: ${jsonEncode(blockStart)}',
        'event: content_block_delta',
        'data: ${jsonEncode(blockDelta)}',
        'event: message_stop',
        'data: ${jsonEncode(msgStop)}',
        '',
      ].join('\n');

      final client = _StreamClient(() async {
        return http.StreamedResponse(Stream.value(_enc(sseData)), 200);
      });

      final provider = CustomProvider(
        baseUrl: 'http://localhost:8080',
        model: 'my-model',
        temperature: 0.7,
        maxTokens: 100,
        apiFormat: CustomApiFormat.anthropicCompatible,
        apiKey: 'key',
        client: client,
      );

      final deltas = await provider
          .generateChatStream(messages: _hiMsg)
          .toList();

      expect(deltas.length, 3);
      expect(deltas[0].toolCalls, isNotNull);
      expect(deltas[0].toolCalls![0].id, 'tool_1');
      expect(deltas[0].toolCalls![0].name, 'get_weather');
      expect(deltas[1].toolCalls![0].arguments, '{"city": "Seoul"}');
      expect(deltas[2].done, true);
    });

    test('throws LlmError on non-200 status', () async {
      final client = _StreamClient(() async {
        return http.StreamedResponse(Stream.value(_enc('error body')), 500);
      });

      final provider = CustomProvider(
        baseUrl: 'http://localhost:8080',
        model: 'my-model',
        temperature: 0.7,
        maxTokens: 100,
        apiFormat: CustomApiFormat.anthropicCompatible,
        apiKey: 'key',
        client: client,
      );

      expect(
        provider.generateChatStream(messages: _hiMsg).toList(),
        throwsA(isA<LlmError>()),
      );
    });

    test('yields done when stream ends without message_stop', () async {
      final sseData = [
        'event: content_block_delta',
        'data: ${jsonEncode({
          'type': 'content_block_delta',
          'index': 0,
          'delta': {'type': 'text_delta', 'text': 'partial'},
        })}',
        '',
      ].join('\n');

      final client = _StreamClient(() async {
        return http.StreamedResponse(Stream.value(_enc(sseData)), 200);
      });

      final provider = CustomProvider(
        baseUrl: 'http://localhost:8080',
        model: 'my-model',
        temperature: 0.7,
        maxTokens: 100,
        apiFormat: CustomApiFormat.anthropicCompatible,
        apiKey: 'key',
        client: client,
      );

      final deltas = await provider
          .generateChatStream(messages: _hiMsg)
          .toList();

      expect(deltas.length, 2);
      expect(deltas[0].content, 'partial');
      expect(deltas[1].done, true);
    });
  });

  group('CustomProvider - Ollama Compatible - generateChatStream', () {
    test('yields content deltas from SSE stream', () async {
      final sseData = [
        'data: ${jsonEncode({
          'choices': [
            {
              'delta': {'content': 'Ollama'},
            },
          ],
        })}',
        'data: [DONE]',
        '',
      ].join('\n');

      final client = _StreamClient(() async {
        return http.StreamedResponse(Stream.value(_enc(sseData)), 200);
      });

      final provider = CustomProvider(
        baseUrl: 'http://localhost:8080',
        model: 'my-model',
        temperature: 0.7,
        maxTokens: 100,
        apiFormat: CustomApiFormat.ollamaCompatible,
        client: client,
      );

      final deltas = await provider
          .generateChatStream(messages: _hiMsg)
          .toList();

      expect(deltas.length, 2);
      expect(deltas[0].content, 'Ollama');
      expect(deltas[1].done, true);
    });

    test('yields tool call deltas from SSE stream', () async {
      final tc1 = {
        'index': 0,
        'id': 'call_42',
        'function': {'name': 'search', 'arguments': '{"q":'},
      };
      final tc2 = {
        'index': 0,
        'function': {'arguments': '"test"}'},
      };
      final sseData = [
        'data: ${jsonEncode({
          'choices': [
            {
              'delta': {
                'tool_calls': [tc1],
              },
            },
          ],
        })}',
        'data: ${jsonEncode({
          'choices': [
            {
              'delta': {
                'tool_calls': [tc2],
              },
            },
          ],
        })}',
        'data: [DONE]',
        '',
      ].join('\n');

      final client = _StreamClient(() async {
        return http.StreamedResponse(Stream.value(_enc(sseData)), 200);
      });

      final provider = CustomProvider(
        baseUrl: 'http://localhost:8080',
        model: 'my-model',
        temperature: 0.7,
        maxTokens: 100,
        apiFormat: CustomApiFormat.ollamaCompatible,
        client: client,
      );

      final deltas = await provider
          .generateChatStream(messages: _hiMsg)
          .toList();

      expect(deltas.length, 3);
      expect(deltas[0].toolCalls, isNotNull);
      expect(deltas[0].toolCalls![0].id, 'call_42');
      expect(deltas[0].toolCalls![0].name, 'search');
      expect(deltas[0].toolCalls![0].arguments, '{"q":');
      expect(deltas[1].toolCalls![0].arguments, '"test"}');
      expect(deltas[2].done, true);
    });

    test('yields done when stream ends without [DONE] marker', () async {
      final sseData = [
        'data: ${jsonEncode({
          'choices': [
            {
              'delta': {'content': 'partial'},
            },
          ],
        })}',
        '',
      ].join('\n');

      final client = _StreamClient(() async {
        return http.StreamedResponse(Stream.value(_enc(sseData)), 200);
      });

      final provider = CustomProvider(
        baseUrl: 'http://localhost:8080',
        model: 'my-model',
        temperature: 0.7,
        maxTokens: 100,
        apiFormat: CustomApiFormat.ollamaCompatible,
        client: client,
      );

      final deltas = await provider
          .generateChatStream(messages: _hiMsg)
          .toList();

      expect(deltas.length, 2);
      expect(deltas[0].content, 'partial');
      expect(deltas[1].done, true);
    });

    test('sends stream:true and no Authorization in request', () async {
      final client = _StreamClientWithRequest((request) async {
        expect(request.headers.containsKey('Authorization'), false);
        final body =
            jsonDecode((request as http.Request).body) as Map<String, dynamic>;
        expect(body['stream'], true);
        return http.StreamedResponse(Stream.value(_enc('data: [DONE]\n')), 200);
      });

      final provider = CustomProvider(
        baseUrl: 'http://localhost:8080',
        model: 'my-model',
        temperature: 0.7,
        maxTokens: 100,
        apiFormat: CustomApiFormat.ollamaCompatible,
        client: client,
      );

      await provider.generateChatStream(messages: _hiMsg).toList();
    });

    test('throws LlmError on non-200 status', () async {
      final client = _StreamClient(() async {
        return http.StreamedResponse(Stream.value(_enc('error')), 500);
      });

      final provider = CustomProvider(
        baseUrl: 'http://localhost:8080',
        model: 'my-model',
        temperature: 0.7,
        maxTokens: 100,
        apiFormat: CustomApiFormat.ollamaCompatible,
        client: client,
      );

      expect(
        provider.generateChatStream(messages: _hiMsg).toList(),
        throwsA(isA<LlmError>()),
      );
    });
  });
}
