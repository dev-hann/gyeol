import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/providers/anthropic_provider.dart';
import 'package:gyeol/providers/custom_provider.dart';
import 'package:gyeol/providers/lllm_provider.dart';
import 'package:gyeol/providers/ollama_provider.dart';
import 'package:gyeol/providers/openai_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('ChatMessageForApi', () {
    test('stores role and optional fields', () {
      final msg = ChatMessageForApi(role: 'user', content: 'hello');
      expect(msg.role, 'user');
      expect(msg.content, 'hello');
      expect(msg.toolCalls, isNull);
      expect(msg.toolCallId, isNull);
    });

    test('stores toolCalls for assistant messages', () {
      final msg = ChatMessageForApi(
        role: 'assistant',
        toolCalls: [
          const ToolCall(
            id: 'call_1',
            name: 'create_layer',
            arguments: '{"name": "L1"}',
          ),
        ],
      );
      expect(msg.role, 'assistant');
      expect(msg.content, isNull);
      expect(msg.toolCalls!.length, 1);
      expect(msg.toolCalls!.first.name, 'create_layer');
    });

    test('stores toolCallId for tool messages', () {
      final msg = ChatMessageForApi(
        role: 'tool',
        content: '{"status": "ok"}',
        toolCallId: 'call_1',
      );
      expect(msg.role, 'tool');
      expect(msg.toolCallId, 'call_1');
    });
  });

  group('ChatResponse', () {
    test('stores content for text response', () {
      final response = ChatResponse(content: 'Hello!');
      expect(response.content, 'Hello!');
      expect(response.toolCalls, isNull);
    });

    test('stores toolCalls for tool response', () {
      final response = ChatResponse(
        toolCalls: [
          const ToolCall(id: 'call_1', name: 'create_layer', arguments: '{}'),
        ],
      );
      expect(response.content, isNull);
      expect(response.toolCalls!.length, 1);
    });

    test('stores both content and toolCalls', () {
      final response = ChatResponse(
        content: 'I will create a layer.',
        toolCalls: [
          const ToolCall(id: 'call_1', name: 'create_layer', arguments: '{}'),
        ],
      );
      expect(response.content, 'I will create a layer.');
      expect(response.toolCalls!.length, 1);
    });
  });

  group('ToolDefinition', () {
    test('stores name, description, and parameters', () {
      final tool = ToolDefinition(
        name: 'create_layer',
        description: 'Creates a new layer',
        parameters: {
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
          },
          'required': ['name'],
        },
      );
      expect(tool.name, 'create_layer');
      expect(tool.description, 'Creates a new layer');
      expect(tool.parameters['type'], 'object');
    });
  });

  group('ToolCall', () {
    test('stores id, name, and arguments', () {
      final call = ToolCall(
        id: 'call_abc',
        name: 'run_thread',
        arguments: '{"layerId": 1}',
      );
      expect(call.id, 'call_abc');
      expect(call.name, 'run_thread');
      expect(call.arguments, '{"layerId": 1}');
    });
  });

  group('OpenAIProvider - generateChat', () {
    test('returns ChatResponse with content on text response', () async {
      final mockClient = MockClient((request) async {
        expect(
          request.url.toString(),
          'https://api.openai.com/v1/chat/completions',
        );
        expect(request.headers['Authorization'], 'Bearer test-key');
        expect(request.headers['Content-Type'], 'application/json');

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

      final response = await provider.generateChat(
        messages: [
          const ChatMessageForApi(role: 'system', content: 'You are helpful.'),
          const ChatMessageForApi(role: 'user', content: 'Hi'),
        ],
      );

      expect(response.content, 'Hello from chat!');
      expect(response.toolCalls, isNull);
    });

    test('returns ChatResponse with toolCalls when tools are used', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': null,
                  'tool_calls': [
                    {
                      'id': 'call_abc123',
                      'type': 'function',
                      'function': {
                        'name': 'create_layer',
                        'arguments': '{"name": "Layer1"}',
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

      final response = await provider.generateChat(
        messages: [
          const ChatMessageForApi(role: 'user', content: 'Create a layer'),
        ],
        tools: [
          ToolDefinition(
            name: 'create_layer',
            description: 'Creates a layer',
            parameters: <String, dynamic>{
              'type': 'object',
              'properties': <String, dynamic>{},
            },
          ),
        ],
      );

      expect(response.content, isNull);
      expect(response.toolCalls, isNotNull);
      expect(response.toolCalls!.length, 1);
      expect(response.toolCalls!.first.id, 'call_abc123');
      expect(response.toolCalls!.first.name, 'create_layer');
      expect(response.toolCalls!.first.arguments, '{"name": "Layer1"}');
    });

    test('sends correct request body with messages and tools', () async {
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], 'gpt-4o');
        expect(body['temperature'], 0.7);
        expect(body['max_tokens'], 100);
        expect(body['tool_choice'], 'auto');

        final messages = body['messages'] as List<dynamic>;
        expect(messages.length, 2);
        expect((messages[0] as Map<String, dynamic>)['role'], 'system');
        expect((messages[0] as Map<String, dynamic>)['content'], 'Be helpful');
        expect((messages[1] as Map<String, dynamic>)['role'], 'user');
        expect((messages[1] as Map<String, dynamic>)['content'], 'Do stuff');

        final tools = body['tools'] as List<dynamic>;
        expect(tools.length, 1);
        final tool = tools[0] as Map<String, dynamic>;
        expect(tool['type'], 'function');
        final fn = tool['function'] as Map<String, dynamic>;
        expect(fn['name'], 'run_thread');
        expect(fn['description'], 'Runs a thread');
        expect((fn['parameters'] as Map<String, dynamic>)['type'], 'object');

        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'Done'},
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

      await provider.generateChat(
        messages: [
          const ChatMessageForApi(role: 'system', content: 'Be helpful'),
          const ChatMessageForApi(role: 'user', content: 'Do stuff'),
        ],
        tools: [
          ToolDefinition(
            name: 'run_thread',
            description: 'Runs a thread',
            parameters: <String, dynamic>{
              'type': 'object',
              'properties': <String, dynamic>{},
            },
          ),
        ],
      );
    });

    test('does not include tools array when tools is null', () async {
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body.containsKey('tools'), false);
        expect(body.containsKey('tool_choice'), false);

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

      await provider.generateChat(
        messages: [const ChatMessageForApi(role: 'user', content: 'hi')],
      );
    });

    test('sends tool message with tool_call_id', () async {
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final messages = body['messages'] as List<dynamic>;
        expect(messages.length, 3);
        final toolMsg = messages[2] as Map<String, dynamic>;
        expect(toolMsg['role'], 'tool');
        expect(toolMsg['content'], '{"status": "ok"}');
        expect(toolMsg['tool_call_id'], 'call_abc123');

        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'Layer created!'},
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

      await provider.generateChat(
        messages: [
          const ChatMessageForApi(role: 'user', content: 'Create a layer'),
          const ChatMessageForApi(
            role: 'assistant',
            toolCalls: [
              ToolCall(
                id: 'call_abc123',
                name: 'create_layer',
                arguments: '{}',
              ),
            ],
          ),
          const ChatMessageForApi(
            role: 'tool',
            content: '{"status": "ok"}',
            toolCallId: 'call_abc123',
          ),
        ],
      );
    });

    test('sends assistant message with tool_calls', () async {
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final messages = body['messages'] as List<dynamic>;
        final assistantMsg = messages[1] as Map<String, dynamic>;
        expect(assistantMsg['role'], 'assistant');
        final tcList = assistantMsg['tool_calls'] as List<dynamic>;
        expect(tcList.length, 1);
        final tc = tcList[0] as Map<String, dynamic>;
        expect(tc['id'], 'call_abc123');
        expect(tc['type'], 'function');
        final fn = tc['function'] as Map<String, dynamic>;
        expect(fn['name'], 'create_layer');
        expect(fn['arguments'], '{}');

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

      await provider.generateChat(
        messages: [
          const ChatMessageForApi(role: 'user', content: 'go'),
          const ChatMessageForApi(
            role: 'assistant',
            toolCalls: [
              ToolCall(
                id: 'call_abc123',
                name: 'create_layer',
                arguments: '{}',
              ),
            ],
          ),
        ],
      );
    });

    test('throws LlmError when apiKey is empty', () {
      final provider = OpenAIProvider(
        apiKey: '',
        model: 'gpt-4o',
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

    test('throws LlmError on non-200 status', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"error": "rate limit"}', 429);
      });

      final provider = OpenAIProvider(
        apiKey: 'test-key',
        model: 'gpt-4o',
        temperature: 0.7,
        maxTokens: 100,
        client: mockClient,
      );

      expect(
        provider.generateChat(
          messages: [const ChatMessageForApi(role: 'user', content: 'hi')],
        ),
        throwsA(isA<LlmError>()),
      );
    });

    test('throws LlmError on malformed response', () async {
      final mockClient = MockClient((request) async {
        return http.Response('not valid json{{{', 200);
      });

      final provider = OpenAIProvider(
        apiKey: 'test-key',
        model: 'gpt-4o',
        temperature: 0.7,
        maxTokens: 100,
        client: mockClient,
      );

      expect(
        provider.generateChat(
          messages: [const ChatMessageForApi(role: 'user', content: 'hi')],
        ),
        throwsA(isA<LlmError>()),
      );
    });
  });

  group('AnthropicProvider - generateChat', () {
    test('returns ChatResponse with content on text response', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), 'https://api.anthropic.com/v1/messages');
        expect(request.headers['x-api-key'], 'test-key');
        expect(request.headers['anthropic-version'], '2023-06-01');

        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': 'Hello from Claude chat!'},
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
        messages: [const ChatMessageForApi(role: 'user', content: 'Hi')],
      );

      expect(response.content, 'Hello from Claude chat!');
      expect(response.toolCalls, isNull);
    });

    test(
      'extracts system message from messages and sends as parameter',
      () async {
        final mockClient = MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['system'], 'You are a scheduler AI');

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

        await provider.generateChat(
          messages: [
            const ChatMessageForApi(
              role: 'system',
              content: 'You are a scheduler AI',
            ),
            const ChatMessageForApi(role: 'user', content: 'Hello'),
          ],
        );
      },
    );

    test('returns ChatResponse with toolCalls for tool_use blocks', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': 'I will create a layer.'},
              {
                'type': 'tool_use',
                'id': 'toolu_abc123',
                'name': 'create_layer',
                'input': {'name': 'Layer1'},
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
        messages: [
          const ChatMessageForApi(role: 'user', content: 'Create a layer'),
        ],
        tools: [
          ToolDefinition(
            name: 'create_layer',
            description: 'Creates a layer',
            parameters: <String, dynamic>{
              'type': 'object',
              'properties': <String, dynamic>{},
            },
          ),
        ],
      );

      expect(response.content, 'I will create a layer.');
      expect(response.toolCalls, isNotNull);
      expect(response.toolCalls!.length, 1);
      expect(response.toolCalls!.first.id, 'toolu_abc123');
      expect(response.toolCalls!.first.name, 'create_layer');
      expect(response.toolCalls!.first.arguments, '{"name":"Layer1"}');
    });

    test('sends tools in Anthropic format with input_schema', () async {
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['tool_choice'], {'type': 'auto'});

        final tools = body['tools'] as List<dynamic>;
        expect(tools.length, 1);
        final tool = tools[0] as Map<String, dynamic>;
        expect(tool['name'], 'run_thread');
        expect(tool['description'], 'Runs a thread');
        expect(tool.containsKey('input_schema'), true);
        expect(
          (tool['input_schema'] as Map<String, dynamic>)['type'],
          'object',
        );

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

      await provider.generateChat(
        messages: [const ChatMessageForApi(role: 'user', content: 'Run it')],
        tools: [
          ToolDefinition(
            name: 'run_thread',
            description: 'Runs a thread',
            parameters: <String, dynamic>{
              'type': 'object',
              'properties': <String, dynamic>{},
            },
          ),
        ],
      );
    });

    test('does not include tools when tools is null', () async {
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body.containsKey('tools'), false);
        expect(body.containsKey('tool_choice'), false);

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

      await provider.generateChat(
        messages: [const ChatMessageForApi(role: 'user', content: 'hi')],
      );
    });

    test('sends tool_result message with tool_use_id', () async {
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final messages = body['messages'] as List<dynamic>;
        expect(messages.length, 3);
        final toolResultMsg = messages[2] as Map<String, dynamic>;
        expect(toolResultMsg['role'], 'user');
        final contentList = toolResultMsg['content'] as List<dynamic>;
        expect(contentList.length, 1);
        final block = contentList[0] as Map<String, dynamic>;
        expect(block['type'], 'tool_result');
        expect(block['tool_use_id'], 'toolu_abc123');
        expect(block['content'], '{"status": "ok"}');

        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': 'Layer created!'},
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

      await provider.generateChat(
        messages: [
          const ChatMessageForApi(role: 'user', content: 'Create a layer'),
          const ChatMessageForApi(
            role: 'assistant',
            toolCalls: [
              ToolCall(
                id: 'toolu_abc123',
                name: 'create_layer',
                arguments: '{}',
              ),
            ],
          ),
          const ChatMessageForApi(
            role: 'tool',
            content: '{"status": "ok"}',
            toolCallId: 'toolu_abc123',
          ),
        ],
      );
    });

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

    test('throws LlmError on non-200 status', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"error": "bad"}', 401);
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
          messages: [const ChatMessageForApi(role: 'user', content: 'hi')],
        ),
        throwsA(isA<LlmError>()),
      );
    });
  });

  group('OllamaProvider - generateChat', () {
    test('returns ChatResponse with content on text response', () async {
      final mockClient = MockClient((request) async {
        expect(
          request.url.toString(),
          'http://localhost:11434/v1/chat/completions',
        );
        expect(request.headers['Content-Type'], 'application/json');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], 'llama3');
        expect(body['temperature'], 0.7);
        expect(body['max_tokens'], 100);

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

      final response = await provider.generateChat(
        messages: [
          const ChatMessageForApi(role: 'system', content: 'Be helpful'),
          const ChatMessageForApi(role: 'user', content: 'Hi'),
        ],
      );

      expect(response.content, 'Hello from Ollama chat!');
      expect(response.toolCalls, isNull);
    });

    test('returns ChatResponse with toolCalls when tools are used', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': null,
                  'tool_calls': [
                    {
                      'id': 'call_1',
                      'type': 'function',
                      'function': {
                        'name': 'create_layer',
                        'arguments': '{"name":"L1"}',
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

      final response = await provider.generateChat(
        messages: [
          const ChatMessageForApi(role: 'user', content: 'Create layer'),
        ],
        tools: [
          ToolDefinition(
            name: 'create_layer',
            description: 'Creates a layer',
            parameters: <String, dynamic>{
              'type': 'object',
              'properties': <String, dynamic>{},
            },
          ),
        ],
      );

      expect(response.content, isNull);
      expect(response.toolCalls!.length, 1);
      expect(response.toolCalls!.first.name, 'create_layer');
    });

    test('sends correct request body with tools', () async {
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['tool_choice'], 'auto');

        final tools = body['tools'] as List<dynamic>;
        expect(tools.length, 1);
        final tool = tools[0] as Map<String, dynamic>;
        expect(tool['type'], 'function');
        expect(
          (tool['function'] as Map<String, dynamic>)['name'],
          'run_thread',
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

      final provider = OllamaProvider(
        baseUrl: 'http://localhost:11434',
        model: 'llama3',
        temperature: 0.7,
        maxTokens: 100,
        client: mockClient,
      );

      await provider.generateChat(
        messages: [const ChatMessageForApi(role: 'user', content: 'go')],
        tools: [
          ToolDefinition(
            name: 'run_thread',
            description: 'Runs a thread',
            parameters: <String, dynamic>{
              'type': 'object',
              'properties': <String, dynamic>{},
            },
          ),
        ],
      );
    });

    test('strips trailing slash from baseUrl', () async {
      final mockClient = MockClient((request) async {
        expect(
          request.url.toString(),
          'http://localhost:11434/v1/chat/completions',
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

      final provider = OllamaProvider(
        baseUrl: 'http://localhost:11434/',
        model: 'llama3',
        temperature: 0.7,
        maxTokens: 100,
        client: mockClient,
      );

      final response = await provider.generateChat(
        messages: [const ChatMessageForApi(role: 'user', content: 'hi')],
      );
      expect(response.content, 'ok');
    });

    test('throws LlmError on non-200 status', () async {
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
        provider.generateChat(
          messages: [const ChatMessageForApi(role: 'user', content: 'hi')],
        ),
        throwsA(isA<LlmError>()),
      );
    });

    test('throws LlmError on malformed response', () async {
      final mockClient = MockClient((request) async {
        return http.Response('not json{{{', 200);
      });

      final provider = OllamaProvider(
        baseUrl: 'http://localhost:11434',
        model: 'llama3',
        temperature: 0.7,
        maxTokens: 100,
        client: mockClient,
      );

      expect(
        provider.generateChat(
          messages: [const ChatMessageForApi(role: 'user', content: 'hi')],
        ),
        throwsA(isA<LlmError>()),
      );
    });
  });

  group('CustomProvider - generateChat', () {
    test(
      'delegates to OpenAI format when apiFormat is openAICompatible',
      () async {
        final mockClient = MockClient((request) async {
          expect(
            request.url.toString(),
            'http://localhost:8080/v1/chat/completions',
          );
          expect(request.headers['Authorization'], 'Bearer test-key');

          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': 'Custom OpenAI chat!'},
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

        final response = await provider.generateChat(
          messages: [const ChatMessageForApi(role: 'user', content: 'hi')],
        );
        expect(response.content, 'Custom OpenAI chat!');
      },
    );

    test(
      'delegates to Anthropic format when apiFormat is anthropicCompatible',
      () async {
        final mockClient = MockClient((request) async {
          expect(request.url.toString(), 'http://localhost:8080/v1/messages');
          expect(request.headers['x-api-key'], 'test-key');

          return http.Response(
            jsonEncode({
              'content': [
                {'type': 'text', 'text': 'Custom Anthropic chat!'},
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

        final response = await provider.generateChat(
          messages: [const ChatMessageForApi(role: 'user', content: 'hi')],
        );
        expect(response.content, 'Custom Anthropic chat!');
      },
    );

    test(
      'delegates to Ollama format when apiFormat is ollamaCompatible',
      () async {
        final mockClient = MockClient((request) async {
          expect(
            request.url.toString(),
            'http://localhost:8080/v1/chat/completions',
          );

          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': 'Custom Ollama chat!'},
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
          apiFormat: CustomApiFormat.ollamaCompatible,
          client: mockClient,
        );

        final response = await provider.generateChat(
          messages: [const ChatMessageForApi(role: 'user', content: 'hi')],
        );
        expect(response.content, 'Custom Ollama chat!');
      },
    );
  });

  group('LlmProvider - generateChat in abstract', () {
    test('generateChat is part of LlmProvider interface', () {
      final provider = _FakeLlmProviderForChat();
      expect(provider, isA<LlmProvider>());
    });

    test('generateChat can be overridden', () async {
      final provider = _FakeLlmProviderForChat();
      final response = await provider.generateChat(
        messages: [const ChatMessageForApi(role: 'user', content: 'hi')],
      );
      expect(response.content, 'fake-chat');
      expect(response.toolCalls, isNull);
    });
  });
}

class _FakeLlmProviderForChat extends LlmProvider {
  @override
  Future<String> generate(String prompt) async => 'generated: $prompt';

  @override
  Future<String> generateWithSystem(String system, String user) async =>
      'system: $system user: $user';

  @override
  Future<ChatResponse> generateChat({
    required List<ChatMessageForApi> messages,
    List<ToolDefinition>? tools,
  }) async => const ChatResponse(content: 'fake-chat');

  @override
  Stream<ChatStreamDelta> generateChatStream({
    required List<ChatMessageForApi> messages,
    List<ToolDefinition>? tools,
  }) async* {
    yield const ChatStreamDelta(content: 'fake-stream', done: true);
  }

  @override
  void close() {}
}
