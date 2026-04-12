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

  group('OllamaProvider - generateChat', () {
    test('returns ChatResponse with content on success', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'Hello from Ollama chat!'},
              },
            ],
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

      final result = await provider.generateChat(messages: _hiMsg);
      expect(result.content, 'Hello from Ollama chat!');
      expect(result.toolCalls, isNull);
    });

    test('returns ChatResponse with tool calls', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'tool_calls': [
                    {
                      'id': 'call_abc',
                      'type': 'function',
                      'function': {
                        'name': 'get_weather',
                        'arguments': '{"city":"Seoul"}',
                      },
                    },
                  ],
                },
              },
            ],
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

      final result = await provider.generateChat(messages: _hiMsg);
      expect(result.content, isNull);
      expect(result.toolCalls, isNotNull);
      expect(result.toolCalls!.length, 1);
      expect(result.toolCalls![0].id, 'call_abc');
      expect(result.toolCalls![0].name, 'get_weather');
      expect(result.toolCalls![0].arguments, '{"city":"Seoul"}');
    });

    test('returns ChatResponse with both content and tool calls', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': 'Let me check the weather.',
                  'tool_calls': [
                    {
                      'id': 'call_1',
                      'type': 'function',
                      'function': {
                        'name': 'get_weather',
                        'arguments': '{"city":"Tokyo"}',
                      },
                    },
                  ],
                },
              },
            ],
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

      final result = await provider.generateChat(messages: _hiMsg);
      expect(result.content, 'Let me check the weather.');
      expect(result.toolCalls!.length, 1);
    });

    test('throws LlmError on non-200 status', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"error": "rate limited"}', 429);
      });

      final provider = OllamaProvider(
        baseUrl: 'http://localhost:11434',
        model: 'llama3',
        temperature: 0.7,
        maxTokens: 100,
        client: mockClient,
      );

      expect(provider.generateChat(messages: _hiMsg), throwsA(isA<LlmError>()));
    });

    test('throws LlmError on malformed JSON', () async {
      final mockClient = MockClient((request) async {
        return http.Response('not json at all', 200);
      });

      final provider = OllamaProvider(
        baseUrl: 'http://localhost:11434',
        model: 'llama3',
        temperature: 0.7,
        maxTokens: 100,
        client: mockClient,
      );

      expect(provider.generateChat(messages: _hiMsg), throwsA(isA<LlmError>()));
    });

    test(
      'returns null content and null toolCalls when choices empty',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'choices': <Map<String, dynamic>>[]}),
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

        final result = await provider.generateChat(messages: _hiMsg);
        expect(result.content, isNull);
        expect(result.toolCalls, isNull);
      },
    );

    test('returns nulls when choices is null', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({}), 200);
      });

      final provider = OllamaProvider(
        baseUrl: 'http://localhost:11434',
        model: 'llama3',
        temperature: 0.7,
        maxTokens: 100,
        client: mockClient,
      );

      final result = await provider.generateChat(messages: _hiMsg);
      expect(result.content, isNull);
      expect(result.toolCalls, isNull);
    });

    test('sends tools in request body when provided', () async {
      late String capturedBody;

      final mockClient = MockClient((request) async {
        capturedBody = request.body;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'tool response'},
              },
            ],
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

      const tools = [
        ToolDefinition(
          name: 'get_weather',
          description: 'Get weather',
          parameters: {'type': 'object', 'properties': <String, dynamic>{}},
        ),
      ];

      await provider.generateChat(messages: _hiMsg, tools: tools);

      final body = jsonDecode(capturedBody) as Map<String, dynamic>;
      expect(body['tool_choice'], 'auto');
      final bodyTools = body['tools'] as List<dynamic>;
      expect(bodyTools.length, 1);
      final fn =
          (bodyTools[0] as Map<String, dynamic>)['function']
              as Map<String, dynamic>;
      expect(fn['name'], 'get_weather');
      expect(fn['description'], 'Get weather');
    });

    test('sends messages with tool_calls and tool_call_id', () async {
      late String capturedBody;

      final mockClient = MockClient((request) async {
        capturedBody = request.body;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'result'},
              },
            ],
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

      const messages = [
        ChatMessageForApi(role: 'user', content: 'weather'),
        ChatMessageForApi(
          role: 'assistant',
          toolCalls: [
            ToolCall(
              id: 'call_1',
              name: 'get_weather',
              arguments: '{"city":"Seoul"}',
            ),
          ],
        ),
        ChatMessageForApi(
          role: 'tool',
          content: '{"temp": 22}',
          toolCallId: 'call_1',
        ),
      ];

      await provider.generateChat(messages: messages);

      final body = jsonDecode(capturedBody) as Map<String, dynamic>;
      final bodyMessages = body['messages'] as List<dynamic>;

      expect(bodyMessages.length, 3);

      final msg0 = bodyMessages[0] as Map<String, dynamic>;
      expect(msg0['role'], 'user');
      expect(msg0['content'], 'weather');

      final msg1 = bodyMessages[1] as Map<String, dynamic>;
      expect(msg1['role'], 'assistant');
      expect(msg1['tool_calls'], isNotNull);
      final tc =
          (msg1['tool_calls'] as List<dynamic>)[0] as Map<String, dynamic>;
      expect(tc['id'], 'call_1');
      expect(tc['type'], 'function');
      final tcFn = tc['function'] as Map<String, dynamic>;
      expect(tcFn['name'], 'get_weather');

      final msg2 = bodyMessages[2] as Map<String, dynamic>;
      expect(msg2['role'], 'tool');
      expect(msg2['tool_call_id'], 'call_1');
      expect(msg2['content'], '{"temp": 22}');
    });

    test('omits tools key when tools list is empty', () async {
      late String capturedBody;

      final mockClient = MockClient((request) async {
        capturedBody = request.body;
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

      final provider = OllamaProvider(
        baseUrl: 'http://localhost:11434',
        model: 'llama3',
        temperature: 0.7,
        maxTokens: 100,
        client: mockClient,
      );

      await provider.generateChat(messages: _hiMsg, tools: []);

      final body = jsonDecode(capturedBody) as Map<String, dynamic>;
      expect(body.containsKey('tools'), isFalse);
      expect(body.containsKey('tool_choice'), isFalse);
    });

    test('throws LlmError on non-map JSON body', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode([1, 2, 3]), 200);
      });

      final provider = OllamaProvider(
        baseUrl: 'http://localhost:11434',
        model: 'llama3',
        temperature: 0.7,
        maxTokens: 100,
        client: mockClient,
      );

      expect(provider.generateChat(messages: _hiMsg), throwsA(isA<LlmError>()));
    });

    test('uses resolveEndpoint for URL', () async {
      late Uri capturedUrl;

      final mockClient = MockClient((request) async {
        capturedUrl = request.url;
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

      final provider = OllamaProvider(
        baseUrl: 'http://localhost:11434',
        model: 'llama3',
        temperature: 0.7,
        maxTokens: 100,
        client: mockClient,
      );

      await provider.generateChat(messages: _hiMsg);
      expect(
        capturedUrl.toString(),
        'http://localhost:11434/v1/chat/completions',
      );
    });

    test('includes top_p in request body', () async {
      late String capturedBody;

      final mockClient = MockClient((request) async {
        capturedBody = request.body;
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

      final provider = OllamaProvider(
        baseUrl: 'http://localhost:11434',
        model: 'llama3',
        temperature: 0.7,
        maxTokens: 100,
        topP: 0.9,
        client: mockClient,
      );

      await provider.generateChat(messages: _hiMsg);

      final body = jsonDecode(capturedBody) as Map<String, dynamic>;
      expect(body['top_p'], 0.9);
    });
  });
}
