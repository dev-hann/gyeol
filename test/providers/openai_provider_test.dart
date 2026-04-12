import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/providers/lllm_provider.dart';
import 'package:gyeol/providers/openai_provider.dart';
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

  group('OpenAIProvider - generateChatStream', () {
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

      final provider = OpenAIProvider(
        apiKey: 'test-key',
        model: 'gpt-4o',
        temperature: 0.7,
        maxTokens: 100,
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

      final provider = OpenAIProvider(
        apiKey: 'test-key',
        model: 'gpt-4o',
        temperature: 0.7,
        maxTokens: 100,
        client: client,
      );

      final deltas = await provider
          .generateChatStream(
            messages: const [
              ChatMessageForApi(role: 'user', content: 'weather'),
            ],
          )
          .toList();

      expect(deltas.length, 3);
      expect(deltas[0].toolCalls, isNotNull);
      expect(deltas[0].toolCalls!.length, 1);
      expect(deltas[0].toolCalls![0].id, 'call_1');
      expect(deltas[0].toolCalls![0].name, 'get_weather');
      expect(deltas[0].toolCalls![0].arguments, '{"city":');
      expect(deltas[1].toolCalls, isNotNull);
      expect(deltas[1].toolCalls![0].arguments, '"Seoul"}');
      expect(deltas[2].done, true);
    });

    test('throws LlmError on non-200 status', () async {
      final client = _StreamClient(() async {
        return http.StreamedResponse(Stream.value(_enc('error')), 500);
      });

      final provider = OpenAIProvider(
        apiKey: 'test-key',
        model: 'gpt-4o',
        temperature: 0.7,
        maxTokens: 100,
        client: client,
      );

      expect(
        provider.generateChatStream(messages: _hiMsg).toList(),
        throwsA(isA<LlmError>()),
      );
    });

    test('throws LlmError when apiKey is empty', () async {
      final provider = OpenAIProvider(
        apiKey: '',
        model: 'gpt-4o',
        temperature: 0.7,
        maxTokens: 100,
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
              'delta': {'content': 'Hi'},
            },
          ],
        })}',
        '',
      ].join('\n');

      final client = _StreamClient(() async {
        return http.StreamedResponse(Stream.value(_enc(sseData)), 200);
      });

      final provider = OpenAIProvider(
        apiKey: 'test-key',
        model: 'gpt-4o',
        temperature: 0.7,
        maxTokens: 100,
        client: client,
      );

      final deltas = await provider
          .generateChatStream(messages: _hiMsg)
          .toList();

      expect(deltas.length, 2);
      expect(deltas[0].content, 'Hi');
      expect(deltas[1].done, true);
    });

    test('skips malformed SSE lines without crashing', () async {
      final sseData = [
        'not a data line',
        'data: not valid json{{{',
        'data: ${jsonEncode({
          'choices': [
            {
              'delta': {'content': 'ok'},
            },
          ],
        })}',
        'data: [DONE]',
        '',
      ].join('\n');

      final client = _StreamClient(() async {
        return http.StreamedResponse(Stream.value(_enc(sseData)), 200);
      });

      final provider = OpenAIProvider(
        apiKey: 'test-key',
        model: 'gpt-4o',
        temperature: 0.7,
        maxTokens: 100,
        client: client,
      );

      final deltas = await provider
          .generateChatStream(messages: _hiMsg)
          .toList();

      expect(deltas.length, 2);
      expect(deltas[0].content, 'ok');
      expect(deltas[1].done, true);
    });

    test('sends stream:true in request body', () async {
      late String capturedBody;

      final client = _StreamClientWithRequest((request) async {
        capturedBody = (request as http.Request).body;
        return http.StreamedResponse(Stream.value(_enc('data: [DONE]\n')), 200);
      });

      final provider = OpenAIProvider(
        apiKey: 'test-key',
        model: 'gpt-4o',
        temperature: 0.7,
        maxTokens: 100,
        client: client,
      );

      await provider.generateChatStream(messages: _hiMsg).toList();

      final body = jsonDecode(capturedBody) as Map<String, dynamic>;
      expect(body['stream'], true);
      expect(body['model'], 'gpt-4o');
    });
  });
}
