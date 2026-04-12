import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/providers/lllm_provider.dart';
import 'package:gyeol/providers/ollama_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

List<int> _enc(String s) => utf8.encode(s);

class _StreamClient extends http.BaseClient {
  _StreamClient(this._handler);
  final Future<http.StreamedResponse> Function() _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => _handler();
}

const _hiMsg = [ChatMessageForApi(role: 'user', content: 'hi')];

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

    test('generateWithSystem throws LlmError with parse message '
        'on malformed JSON', () async {
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
    });

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

    test('generateWithSystem uses correct URL '
        'when baseUrl has no trailing slash', () async {
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
    });
  });

  group('OllamaProvider - generateChatStream', () {
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

      final provider = OllamaProvider(
        baseUrl: 'http://localhost:11434',
        model: 'llama3',
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

      final provider = OllamaProvider(
        baseUrl: 'http://localhost:11434',
        model: 'llama3',
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
        return http.StreamedResponse(Stream.value(_enc('error body')), 500);
      });

      final provider = OllamaProvider(
        baseUrl: 'http://localhost:11434',
        model: 'llama3',
        temperature: 0.7,
        maxTokens: 100,
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
              'delta': {'content': 'Hi'},
            },
          ],
        })}',
        '',
      ].join('\n');

      final client = _StreamClient(() async {
        return http.StreamedResponse(Stream.value(_enc(sseData)), 200);
      });

      final provider = OllamaProvider(
        baseUrl: 'http://localhost:11434',
        model: 'llama3',
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

      final provider = OllamaProvider(
        baseUrl: 'http://localhost:11434',
        model: 'llama3',
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
  });
}
