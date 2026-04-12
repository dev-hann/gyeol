import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/providers/anthropic_provider.dart';
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

  group('AnthropicProvider - generateChat', () {
    test('throws LlmError when apiKey is empty', () {
      final provider = AnthropicProvider(
        apiKey: '',
        model: 'claude-3-sonnet',
        temperature: 0.7,
        maxTokens: 100,
      );

      expect(
        provider.generateChat(
          messages: [const ChatMessageForApi(role: 'user', content: 'hi')],
        ),
        throwsA(isA<LlmError>()),
      );
    });

    test('returns text content from chat response', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), 'https://api.anthropic.com/v1/messages');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final messages = body['messages'] as List<dynamic>;
        expect(messages.length, 1);
        expect((messages[0] as Map<String, dynamic>)['role'], 'user');
        expect((messages[0] as Map<String, dynamic>)['content'], 'hello');

        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': 'Hi from Claude!'},
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

      final response = await provider.generateChat(
        messages: const [ChatMessageForApi(role: 'user', content: 'hello')],
      );

      expect(response.content, 'Hi from Claude!');
      expect(response.toolCalls, isNull);
    });

    test('parses tool_use blocks into toolCalls', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': 'Let me check that.'},
              {
                'type': 'tool_use',
                'id': 'tool_123',
                'name': 'get_weather',
                'input': {'city': 'Seoul'},
              },
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

      final response = await provider.generateChat(
        messages: const [ChatMessageForApi(role: 'user', content: 'weather?')],
        tools: [
          const ToolDefinition(
            name: 'get_weather',
            description: 'Get weather',
            parameters: {
              'type': 'object',
              'properties': {
                'city': {'type': 'string'},
              },
            },
          ),
        ],
      );

      expect(response.content, 'Let me check that.');
      expect(response.toolCalls, isNotNull);
      expect(response.toolCalls!.length, 1);
      expect(response.toolCalls![0].id, 'tool_123');
      expect(response.toolCalls![0].name, 'get_weather');
      expect(response.toolCalls![0].arguments, jsonEncode({'city': 'Seoul'}));
    });

    test(
      'extracts system prompt from messages and sends as top-level field',
      () async {
        final mockClient = MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['system'], 'You are a bot');
          final messages = body['messages'] as List<dynamic>;
          expect(messages.length, 1);
          expect((messages[0] as Map<String, dynamic>)['role'], 'user');

          return http.Response(
            jsonEncode({
              'content': [
                {'type': 'text', 'text': 'ok'},
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

        final response = await provider.generateChat(
          messages: const [
            ChatMessageForApi(role: 'system', content: 'You are a bot'),
            ChatMessageForApi(role: 'user', content: 'hi'),
          ],
        );

        expect(response.content, 'ok');
      },
    );

    test(
      'converts tool role messages to user with tool_result content',
      () async {
        final mockClient = MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final messages = body['messages'] as List<dynamic>;
          expect(messages.length, 2);

          final toolMsg = messages[0] as Map<String, dynamic>;
          expect(toolMsg['role'], 'user');
          final toolContent = toolMsg['content'] as List<dynamic>;
          expect(toolContent.length, 1);
          expect(
            (toolContent[0] as Map<String, dynamic>)['type'],
            'tool_result',
          );
          expect(
            (toolContent[0] as Map<String, dynamic>)['tool_use_id'],
            'call_1',
          );

          return http.Response(
            jsonEncode({
              'content': [
                {'type': 'text', 'text': 'processed'},
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

        final response = await provider.generateChat(
          messages: const [
            ChatMessageForApi(
              role: 'tool',
              content: 'result data',
              toolCallId: 'call_1',
            ),
            ChatMessageForApi(role: 'user', content: 'next'),
          ],
        );

        expect(response.content, 'processed');
      },
    );

    test(
      'converts assistant messages with toolCalls to Anthropic format',
      () async {
        final mockClient = MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final messages = body['messages'] as List<dynamic>;
          expect(messages.length, 2);

          final assistantMsg = messages[0] as Map<String, dynamic>;
          expect(assistantMsg['role'], 'assistant');
          final content = assistantMsg['content'] as List<dynamic>;
          expect(content.length, 2);
          expect((content[0] as Map<String, dynamic>)['type'], 'text');
          expect((content[0] as Map<String, dynamic>)['text'], 'thinking');
          expect((content[1] as Map<String, dynamic>)['type'], 'tool_use');
          expect((content[1] as Map<String, dynamic>)['name'], 'search');

          return http.Response(
            jsonEncode({
              'content': [
                {'type': 'text', 'text': 'done'},
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

        final response = await provider.generateChat(
          messages: [
            const ChatMessageForApi(
              role: 'assistant',
              content: 'thinking',
              toolCalls: [
                ToolCall(id: 'tc_1', name: 'search', arguments: '{"q":"test"}'),
              ],
            ),
            const ChatMessageForApi(role: 'user', content: 'go'),
          ],
        );

        expect(response.content, 'done');
      },
    );

    test('combines multiple tool results into single user message', () async {
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final messages = body['messages'] as List<dynamic>;

        final assistantMsg = messages[0] as Map<String, dynamic>;
        expect(assistantMsg['role'], 'assistant');

        final toolResultsMsg = messages[1] as Map<String, dynamic>;
        expect(toolResultsMsg['role'], 'user');
        final content = toolResultsMsg['content'] as List<dynamic>;
        expect(content.length, 2);
        expect((content[0] as Map<String, dynamic>)['type'], 'tool_result');
        expect((content[0] as Map<String, dynamic>)['tool_use_id'], 'call_1');
        expect((content[1] as Map<String, dynamic>)['type'], 'tool_result');
        expect((content[1] as Map<String, dynamic>)['tool_use_id'], 'call_2');

        final userMsg = messages[2] as Map<String, dynamic>;
        expect(userMsg['role'], 'user');
        expect(userMsg['content'], 'next');

        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': 'combined'},
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

      final response = await provider.generateChat(
        messages: const [
          ChatMessageForApi(
            role: 'assistant',
            content: 'thinking',
            toolCalls: [
              ToolCall(id: 'call_1', name: 'a', arguments: '{}'),
              ToolCall(id: 'call_2', name: 'b', arguments: '{}'),
            ],
          ),
          ChatMessageForApi(
            role: 'tool',
            content: 'result1',
            toolCallId: 'call_1',
          ),
          ChatMessageForApi(
            role: 'tool',
            content: 'result2',
            toolCallId: 'call_2',
          ),
          ChatMessageForApi(role: 'user', content: 'next'),
        ],
      );

      expect(response.content, 'combined');
    });

    test('merges consecutive user messages into single message', () async {
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final messages = body['messages'] as List<dynamic>;
        expect(messages.length, 1);
        final msg = messages[0] as Map<String, dynamic>;
        expect(msg['role'], 'user');
        expect(msg['content'], 'hello\nworld');

        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': 'merged!'},
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

      final response = await provider.generateChat(
        messages: const [
          ChatMessageForApi(role: 'user', content: 'hello'),
          ChatMessageForApi(role: 'user', content: 'world'),
        ],
      );

      expect(response.content, 'merged!');
    });

    test('throws LlmError on non-200 status', () async {
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
        provider.generateChat(
          messages: const [ChatMessageForApi(role: 'user', content: 'hi')],
        ),
        throwsA(isA<LlmError>()),
      );
    });

    test('throws LlmError on malformed JSON response', () async {
      final mockClient = MockClient((request) async {
        return http.Response('invalid json{{{', 200);
      });

      final provider = AnthropicProvider(
        apiKey: 'test-key',
        model: 'claude-3-sonnet',
        temperature: 0.7,
        maxTokens: 100,
        client: mockClient,
      );

      expect(
        provider.generateChat(
          messages: const [ChatMessageForApi(role: 'user', content: 'hi')],
        ),
        throwsA(isA<LlmError>()),
      );
    });

    test('sends tools with input_schema when tools are provided', () async {
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final tools = body['tools'] as List<dynamic>;
        expect(tools.length, 1);
        final tool = tools[0] as Map<String, dynamic>;
        expect(tool['name'], 'my_tool');
        expect(tool['input_schema'], isNotNull);
        expect(body['tool_choice'], {'type': 'auto'});

        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': 'used tool'},
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

      final response = await provider.generateChat(
        messages: const [ChatMessageForApi(role: 'user', content: 'go')],
        tools: [
          const ToolDefinition(
            name: 'my_tool',
            description: 'A test tool',
            parameters: <String, dynamic>{
              'type': 'object',
              'properties': <String, dynamic>{},
            },
          ),
        ],
      );

      expect(response.content, 'used tool');
    });

    test('returns null toolCalls when only text content in response', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': 'just text'},
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

      final response = await provider.generateChat(
        messages: const [ChatMessageForApi(role: 'user', content: 'hi')],
      );

      expect(response.content, 'just text');
      expect(response.toolCalls, isNull);
    });
  });

  group('AnthropicProvider - generateChatStream', () {
    test('yields content deltas from SSE stream', () async {
      final sseData = [
        'data: ${jsonEncode({
          'type': 'content_block_delta',
          'index': 0,
          'delta': {'type': 'text_delta', 'text': 'Hello'},
        })}',
        'data: ${jsonEncode({
          'type': 'content_block_delta',
          'index': 0,
          'delta': {'type': 'text_delta', 'text': ' World'},
        })}',
        'data: ${jsonEncode({'type': 'message_stop'})}',
        '',
      ].join('\n');

      final client = _StreamClient(() async {
        return http.StreamedResponse(Stream.value(_enc(sseData)), 200);
      });

      final provider = AnthropicProvider(
        apiKey: 'test-key',
        model: 'claude-3-sonnet',
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
      final blockStart = {
        'type': 'content_block_start',
        'index': 1,
        'content_block': {
          'type': 'tool_use',
          'id': 'toolu_abc',
          'name': 'get_weather',
        },
      };
      final blockDelta1 = {
        'type': 'content_block_delta',
        'index': 1,
        'delta': {'type': 'input_json_delta', 'partial_json': '{"city":'},
      };
      final blockDelta2 = {
        'type': 'content_block_delta',
        'index': 1,
        'delta': {'type': 'input_json_delta', 'partial_json': '"Seoul"}'},
      };
      final msgStop = {'type': 'message_stop'};
      final sseData = [
        'data: ${jsonEncode(blockStart)}',
        'data: ${jsonEncode(blockDelta1)}',
        'data: ${jsonEncode(blockDelta2)}',
        'data: ${jsonEncode(msgStop)}',
        '',
      ].join('\n');

      final client = _StreamClient(() async {
        return http.StreamedResponse(Stream.value(_enc(sseData)), 200);
      });

      final provider = AnthropicProvider(
        apiKey: 'test-key',
        model: 'claude-3-sonnet',
        temperature: 0.7,
        maxTokens: 100,
        client: client,
      );

      final deltas = await provider
          .generateChatStream(messages: _hiMsg)
          .toList();

      expect(deltas.length, 4);
      expect(deltas[0].toolCalls, isNotNull);
      expect(deltas[0].toolCalls!.length, 1);
      expect(deltas[0].toolCalls![0].id, 'toolu_abc');
      expect(deltas[0].toolCalls![0].name, 'get_weather');
      expect(deltas[1].toolCalls, isNotNull);
      expect(deltas[1].toolCalls![0].arguments, '{"city":');
      expect(deltas[2].toolCalls![0].arguments, '"Seoul"}');
      expect(deltas[3].done, true);
    });

    test('throws LlmError on non-200 status', () async {
      final client = _StreamClient(() async {
        return http.StreamedResponse(Stream.value(_enc('error body')), 500);
      });

      final provider = AnthropicProvider(
        apiKey: 'test-key',
        model: 'claude-3-sonnet',
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
      final provider = AnthropicProvider(
        apiKey: '',
        model: 'claude-3-sonnet',
        temperature: 0.7,
        maxTokens: 100,
      );

      expect(
        provider.generateChatStream(messages: _hiMsg).toList(),
        throwsA(isA<LlmError>()),
      );
    });

    test('yields done when stream ends without message_stop', () async {
      final sseData = [
        'data: ${jsonEncode({
          'type': 'content_block_delta',
          'index': 0,
          'delta': {'type': 'text_delta', 'text': 'Hi'},
        })}',
        '',
      ].join('\n');

      final client = _StreamClient(() async {
        return http.StreamedResponse(Stream.value(_enc(sseData)), 200);
      });

      final provider = AnthropicProvider(
        apiKey: 'test-key',
        model: 'claude-3-sonnet',
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
          'type': 'content_block_delta',
          'index': 0,
          'delta': {'type': 'text_delta', 'text': 'ok'},
        })}',
        'data: ${jsonEncode({'type': 'message_stop'})}',
        '',
      ].join('\n');

      final client = _StreamClient(() async {
        return http.StreamedResponse(Stream.value(_enc(sseData)), 200);
      });

      final provider = AnthropicProvider(
        apiKey: 'test-key',
        model: 'claude-3-sonnet',
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

    test('skips SSE with type-mismatched delta without crashing', () async {
      final malformedEvent = jsonEncode({
        'type': 'content_block_delta',
        'index': 0,
        'delta': 'not-a-map',
      });
      final sseData = [
        'data: $malformedEvent',
        'data: ${jsonEncode({
          'type': 'content_block_delta',
          'index': 0,
          'delta': {'type': 'text_delta', 'text': 'ok'},
        })}',
        'data: ${jsonEncode({'type': 'message_stop'})}',
        '',
      ].join('\n');

      final client = _StreamClient(() async {
        return http.StreamedResponse(Stream.value(_enc(sseData)), 200);
      });

      final provider = AnthropicProvider(
        apiKey: 'test-key',
        model: 'claude-3-sonnet',
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

    test('extracts system prompt and sends as top-level field', () async {
      String? capturedBody;

      final sseData = [
        'data: ${jsonEncode({'type': 'message_stop'})}',
        '',
      ].join('\n');

      final client = _StreamClientWithRequest((request) async {
        capturedBody = (request as http.Request).body;
        return http.StreamedResponse(Stream.value(_enc(sseData)), 200);
      });

      final provider = AnthropicProvider(
        apiKey: 'test-key',
        model: 'claude-3-sonnet',
        temperature: 0.7,
        maxTokens: 100,
        client: client,
      );

      await provider
          .generateChatStream(
            messages: const [
              ChatMessageForApi(role: 'system', content: 'You are a bot'),
              ChatMessageForApi(role: 'user', content: 'hi'),
            ],
          )
          .toList();

      final body = jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(body['system'], 'You are a bot');
    });

    test('sends tools in Anthropic stream format', () async {
      final sseData = [
        'data: ${jsonEncode({'type': 'message_stop'})}',
        '',
      ].join('\n');

      final client = _StreamClient(() async {
        return http.StreamedResponse(Stream.value(_enc(sseData)), 200);
      });

      final provider = AnthropicProvider(
        apiKey: 'test-key',
        model: 'claude-3-sonnet',
        temperature: 0.7,
        maxTokens: 100,
        client: client,
      );

      await provider
          .generateChatStream(
            messages: _hiMsg,
            tools: [
              const ToolDefinition(
                name: 'get_weather',
                description: 'Get weather',
                parameters: {
                  'type': 'object',
                  'properties': <String, dynamic>{},
                },
              ),
            ],
          )
          .toList();
    });

    test(
      'converts tool role messages to user with tool_result in stream',
      () async {
        String? capturedBody;

        final sseData = [
          'data: ${jsonEncode({'type': 'message_stop'})}',
          '',
        ].join('\n');

        final client = _StreamClientWithRequest((request) async {
          capturedBody = (request as http.Request).body;
          return http.StreamedResponse(Stream.value(_enc(sseData)), 200);
        });

        final provider = AnthropicProvider(
          apiKey: 'test-key',
          model: 'claude-3-sonnet',
          temperature: 0.7,
          maxTokens: 100,
          client: client,
        );

        await provider
            .generateChatStream(
              messages: const [
                ChatMessageForApi(
                  role: 'tool',
                  content: 'result data',
                  toolCallId: 'call_1',
                ),
                ChatMessageForApi(role: 'user', content: 'next'),
              ],
            )
            .toList();

        final body = jsonDecode(capturedBody!) as Map<String, dynamic>;
        final messages = body['messages'] as List<dynamic>;
        expect(messages.length, 2);

        final toolMsg = messages[0] as Map<String, dynamic>;
        expect(toolMsg['role'], 'user');
        final toolContent = toolMsg['content'] as List<dynamic>;
        expect(toolContent.length, 1);
        expect((toolContent[0] as Map<String, dynamic>)['type'], 'tool_result');
        expect(
          (toolContent[0] as Map<String, dynamic>)['tool_use_id'],
          'call_1',
        );
        expect(
          (toolContent[0] as Map<String, dynamic>)['content'],
          'result data',
        );
      },
    );

    test(
      'converts assistant+toolCalls to Anthropic format in stream',
      () async {
        String? capturedBody;

        final sseData = [
          'data: ${jsonEncode({'type': 'message_stop'})}',
          '',
        ].join('\n');

        final client = _StreamClientWithRequest((request) async {
          capturedBody = (request as http.Request).body;
          return http.StreamedResponse(Stream.value(_enc(sseData)), 200);
        });

        final provider = AnthropicProvider(
          apiKey: 'test-key',
          model: 'claude-3-sonnet',
          temperature: 0.7,
          maxTokens: 100,
          client: client,
        );

        await provider
            .generateChatStream(
              messages: [
                const ChatMessageForApi(
                  role: 'assistant',
                  content: 'thinking',
                  toolCalls: [
                    ToolCall(
                      id: 'tc_1',
                      name: 'search',
                      arguments: '{"q":"test"}',
                    ),
                  ],
                ),
                const ChatMessageForApi(role: 'user', content: 'go'),
              ],
            )
            .toList();

        final body = jsonDecode(capturedBody!) as Map<String, dynamic>;
        final messages = body['messages'] as List<dynamic>;
        expect(messages.length, 2);

        final assistantMsg = messages[0] as Map<String, dynamic>;
        expect(assistantMsg['role'], 'assistant');
        final content = assistantMsg['content'] as List<dynamic>;
        expect(content.length, 2);
        expect((content[0] as Map<String, dynamic>)['type'], 'text');
        expect((content[0] as Map<String, dynamic>)['text'], 'thinking');
        expect((content[1] as Map<String, dynamic>)['type'], 'tool_use');
        expect((content[1] as Map<String, dynamic>)['id'], 'tc_1');
        expect((content[1] as Map<String, dynamic>)['name'], 'search');
        expect((content[1] as Map<String, dynamic>)['input'], {'q': 'test'});
      },
    );

    test(
      'merges consecutive user messages into single message in stream',
      () async {
        String? capturedBody;

        final sseData = [
          'data: ${jsonEncode({'type': 'message_stop'})}',
          '',
        ].join('\n');

        final client = _StreamClientWithRequest((request) async {
          capturedBody = (request as http.Request).body;
          return http.StreamedResponse(Stream.value(_enc(sseData)), 200);
        });

        final provider = AnthropicProvider(
          apiKey: 'test-key',
          model: 'claude-3-sonnet',
          temperature: 0.7,
          maxTokens: 100,
          client: client,
        );

        await provider
            .generateChatStream(
              messages: const [
                ChatMessageForApi(role: 'user', content: 'hello'),
                ChatMessageForApi(role: 'user', content: 'world'),
              ],
            )
            .toList();

        final body = jsonDecode(capturedBody!) as Map<String, dynamic>;
        final messages = body['messages'] as List<dynamic>;
        expect(messages.length, 1);
        final msg = messages[0] as Map<String, dynamic>;
        expect(msg['role'], 'user');
        expect(msg['content'], 'hello\nworld');
      },
    );

    test(
      'combines multiple tool results into single user message in stream',
      () async {
        String? capturedBody;

        final sseData = [
          'data: ${jsonEncode({'type': 'message_stop'})}',
          '',
        ].join('\n');

        final client = _StreamClientWithRequest((request) async {
          capturedBody = (request as http.Request).body;
          return http.StreamedResponse(Stream.value(_enc(sseData)), 200);
        });

        final provider = AnthropicProvider(
          apiKey: 'test-key',
          model: 'claude-3-sonnet',
          temperature: 0.7,
          maxTokens: 100,
          client: client,
        );

        await provider
            .generateChatStream(
              messages: const [
                ChatMessageForApi(
                  role: 'assistant',
                  content: 'thinking',
                  toolCalls: [
                    ToolCall(id: 'call_1', name: 'a', arguments: '{}'),
                    ToolCall(id: 'call_2', name: 'b', arguments: '{}'),
                  ],
                ),
                ChatMessageForApi(
                  role: 'tool',
                  content: 'result1',
                  toolCallId: 'call_1',
                ),
                ChatMessageForApi(
                  role: 'tool',
                  content: 'result2',
                  toolCallId: 'call_2',
                ),
                ChatMessageForApi(role: 'user', content: 'next'),
              ],
            )
            .toList();

        final body = jsonDecode(capturedBody!) as Map<String, dynamic>;
        final messages = body['messages'] as List<dynamic>;

        final assistantMsg = messages[0] as Map<String, dynamic>;
        expect(assistantMsg['role'], 'assistant');

        final toolResultsMsg = messages[1] as Map<String, dynamic>;
        expect(toolResultsMsg['role'], 'user');
        final content = toolResultsMsg['content'] as List<dynamic>;
        expect(content.length, 2);
        expect((content[0] as Map<String, dynamic>)['type'], 'tool_result');
        expect((content[0] as Map<String, dynamic>)['tool_use_id'], 'call_1');
        expect((content[1] as Map<String, dynamic>)['type'], 'tool_result');
        expect((content[1] as Map<String, dynamic>)['tool_use_id'], 'call_2');

        final userMsg = messages[2] as Map<String, dynamic>;
        expect(userMsg['role'], 'user');
        expect(userMsg['content'], 'next');
      },
    );
  });
}
