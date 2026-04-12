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

    test('handles tool_calls with missing function key', () async {
      final sseData = [
        'data: ${jsonEncode({
          'choices': [
            {
              'delta': {
                'tool_calls': [
                  {'index': 0, 'id': 'call_1'},
                ],
              },
            },
          ],
        })}',
        'data: ${jsonEncode({
          'choices': [
            {
              'delta': {
                'tool_calls': [
                  {
                    'index': 0,
                    'function': {'name': 'get_weather', 'arguments': '{}'},
                  },
                ],
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
          .generateChatStream(messages: _hiMsg)
          .toList();

      expect(deltas.length, 3);
      expect(deltas[0].toolCalls, isNotNull);
      expect(deltas[0].toolCalls![0].id, 'call_1');
      expect(deltas[0].toolCalls![0].name, isNull);
      expect(deltas[1].toolCalls![0].name, 'get_weather');
      expect(deltas[2].done, true);
    });

    test('skips SSE with type-mismatched choices without crashing', () async {
      final sseData = [
        'data: ${jsonEncode({'choices': 'not-a-list'})}',
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

    test('sends tool_calls and tool_call_id in messages', () async {
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

      await provider.generateChatStream(messages: messages).toList();

      final body = jsonDecode(capturedBody) as Map<String, dynamic>;
      final bodyMessages = body['messages'] as List<dynamic>;

      expect(bodyMessages.length, 3);

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
  });

  group('OpenAIProvider - generateChat', () {
    test('throws LlmError when apiKey is empty', () {
      final provider = OpenAIProvider(
        apiKey: '',
        model: 'gpt-4o',
        temperature: 0.7,
        maxTokens: 100,
      );

      expect(provider.generateChat(messages: _hiMsg), throwsA(isA<LlmError>()));
    });

    test('returns ChatResponse with content on success', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'Hello from chat!'},
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

      final result = await provider.generateChat(messages: _hiMsg);
      expect(result.content, 'Hello from chat!');
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

      final provider = OpenAIProvider(
        apiKey: 'test-key',
        model: 'gpt-4o',
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

      final provider = OpenAIProvider(
        apiKey: 'test-key',
        model: 'gpt-4o',
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

      final provider = OpenAIProvider(
        apiKey: 'test-key',
        model: 'gpt-4o',
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

      final provider = OpenAIProvider(
        apiKey: 'test-key',
        model: 'gpt-4o',
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

        final provider = OpenAIProvider(
          apiKey: 'test-key',
          model: 'gpt-4o',
          temperature: 0.7,
          maxTokens: 100,
          client: mockClient,
        );

        final result = await provider.generateChat(messages: _hiMsg);
        expect(result.content, isNull);
        expect(result.toolCalls, isNull);
      },
    );

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

      final provider = OpenAIProvider(
        apiKey: 'test-key',
        model: 'gpt-4o',
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

      final provider = OpenAIProvider(
        apiKey: 'test-key',
        model: 'gpt-4o',
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

      final provider = OpenAIProvider(
        apiKey: 'test-key',
        model: 'gpt-4o',
        temperature: 0.7,
        maxTokens: 100,
        client: mockClient,
      );

      await provider.generateChat(messages: _hiMsg, tools: []);

      final body = jsonDecode(capturedBody) as Map<String, dynamic>;
      expect(body.containsKey('tools'), isFalse);
      expect(body.containsKey('tool_choice'), isFalse);
    });

    test('returns nulls when choices is null', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({}), 200);
      });

      final provider = OpenAIProvider(
        apiKey: 'test-key',
        model: 'gpt-4o',
        temperature: 0.7,
        maxTokens: 100,
        client: mockClient,
      );

      final result = await provider.generateChat(messages: _hiMsg);
      expect(result.content, isNull);
      expect(result.toolCalls, isNull);
    });

    test('throws LlmError on non-map JSON body', () async {
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

      expect(provider.generateChat(messages: _hiMsg), throwsA(isA<LlmError>()));
    });
  });
}
