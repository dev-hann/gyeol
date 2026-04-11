import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/repositories/app_repository.dart';
import 'package:gyeol/engine/chat/chat_service.dart';
import 'package:gyeol/engine/chat/tool_registry.dart';
import 'package:gyeol/providers/lllm_provider.dart';

class FakeLlmProvider implements LlmProvider {
  FakeLlmProvider(this._responses);
  final List<ChatResponse> _responses;
  int _callCount = 0;
  final List<List<ChatMessageForApi>> capturedMessages = [];

  @override
  Future<ChatResponse> generateChat({
    required List<ChatMessageForApi> messages,
    List<ToolDefinition>? tools,
  }) async {
    capturedMessages.add(List.of(messages));
    if (_callCount < _responses.length) {
      return _responses[_callCount++];
    }
    return const ChatResponse(content: '');
  }

  @override
  Future<String> generate(String prompt) async => '';

  @override
  Future<String> generateWithSystem(String system, String user) async => '';

  @override
  Stream<ChatStreamDelta> generateChatStream({
    required List<ChatMessageForApi> messages,
    List<ToolDefinition>? tools,
  }) async* {
    yield const ChatStreamDelta(content: '', done: true);
  }

  @override
  void close() {}
}

void main() {
  group('ToolRegistry', () {
    test('getAllTools returns 30 tools', () {
      final tools = ToolRegistry.getAllTools();
      expect(tools, hasLength(30));
      for (final tool in tools) {
        expect(tool.name, isNotEmpty);
        expect(tool.description, isNotEmpty);
        expect(tool.parameters, isA<Map<String, dynamic>>());
      }
    });

    test('getToolByName returns correct tool for each name', () {
      const expectedNames = [
        'create_layer',
        'update_layer',
        'delete_layer',
        'create_worker',
        'update_worker',
        'delete_worker',
        'list_layers',
        'list_workers',
        'list_threads',
        'create_thread',
        'update_thread',
        'delete_thread',
        'run_thread',
        'get_status',
        'assign_worker',
        'unassign_worker',
        'list_logs',
        'list_tasks',
        'get_queue_status',
        'switch_provider',
        'rename_conversation',
        'search_messages',
        'clear_conversation',
        'export_conversation',
        'get_worker_details',
        'submit_task',
      ];
      for (final name in expectedNames) {
        final tool = ToolRegistry.getToolByName(name);
        expect(tool, isNotNull, reason: 'Tool "$name" should exist');
        expect(tool!.name, name);
      }
    });

    test('getToolByName returns null for unknown tool', () {
      expect(ToolRegistry.getToolByName('nonexistent'), isNull);
    });

    test('tool parameter schemas are valid', () {
      final tools = ToolRegistry.getAllTools();
      for (final tool in tools) {
        expect(
          tool.parameters['type'],
          'object',
          reason: '${tool.name} should have type "object"',
        );
        expect(
          tool.parameters['properties'],
          isA<Map<String, dynamic>>(),
          reason: '${tool.name} should have properties',
        );
      }
    });
  });

  group('ChatService', () {
    late AppDatabase db;
    late AppRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = AppRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('handles simple text response', () async {
      final provider = FakeLlmProvider([
        const ChatResponse(content: 'Hello! How can I help?'),
      ]);
      final service = ChatService(provider: provider, repo: repo);

      final result = await service.handleMessage('Hi', []);

      expect(result.assistantResponse, 'Hello! How can I help?');
      expect(result.newMessages, isNotEmpty);
      expect(result.newMessages.first.role, 'user');
      expect(result.newMessages.first.content, 'Hi');
      expect(result.newMessages.last.role, 'assistant');
      expect(result.newMessages.last.content, 'Hello! How can I help?');
    });

    test('handles single tool call then text response', () async {
      await repo.layers.saveLayer(
        const LayerDefinition(
          name: 'L1',
          inputTypes: ['text'],
          outputTypes: ['analysis'],
        ),
      );

      final provider = FakeLlmProvider([
        const ChatResponse(
          toolCalls: [
            ToolCall(id: 'call_1', name: 'list_layers', arguments: '{}'),
          ],
        ),
        const ChatResponse(content: 'I found 1 layer.'),
      ]);

      final service = ChatService(provider: provider, repo: repo);
      final result = await service.handleMessage('Show me layers', []);

      expect(result.assistantResponse, 'I found 1 layer.');
      expect(
        result.newMessages.any(
          (m) => m.role == 'tool' && m.toolName == 'list_layers',
        ),
        isTrue,
      );
    });

    test('handles multiple tool calls in sequence', () async {
      final provider = FakeLlmProvider([
        const ChatResponse(
          toolCalls: [
            ToolCall(id: 'call_1', name: 'list_layers', arguments: '{}'),
          ],
        ),
        const ChatResponse(
          toolCalls: [
            ToolCall(id: 'call_2', name: 'list_workers', arguments: '{}'),
          ],
        ),
        const ChatResponse(content: 'Done listing everything.'),
      ]);

      final service = ChatService(provider: provider, repo: repo);
      final result = await service.handleMessage('List everything', []);

      expect(result.assistantResponse, 'Done listing everything.');
      expect(provider.capturedMessages.length, 3);
    });

    test('respects max 5 iteration limit', () async {
      final responses = List.generate(
        10,
        (i) => ChatResponse(
          toolCalls: [
            ToolCall(id: 'call_$i', name: 'list_layers', arguments: '{}'),
          ],
        ),
      );

      final provider = FakeLlmProvider(responses);
      final service = ChatService(provider: provider, repo: repo);
      final result = await service.handleMessage('Keep listing', []);

      expect(result.assistantResponse, contains('최대 반복'));
      expect(provider.capturedMessages.length, 5);
    });

    test('builds correct message history with system prompt', () async {
      final provider = FakeLlmProvider([const ChatResponse(content: 'ok')]);

      final history = [
        const ChatMessage(
          id: 'm1',
          conversationId: 'conv1',
          role: 'user',
          content: 'previous question',
          createdAt: 1000,
        ),
        const ChatMessage(
          id: 'm2',
          conversationId: 'conv1',
          role: 'assistant',
          content: 'previous answer',
          createdAt: 1001,
        ),
      ];

      final service = ChatService(provider: provider, repo: repo);
      await service.handleMessage('new question', history);

      expect(provider.capturedMessages.length, 1);
      final messages = provider.capturedMessages.first;
      expect(messages.first.role, 'system');
      expect(messages.first.content, contains('Gyeol AI Assistant'));
      expect(messages[1].role, 'user');
      expect(messages[1].content, 'previous question');
      expect(messages[2].role, 'assistant');
      expect(messages[2].content, 'previous answer');
      expect(messages[3].role, 'user');
      expect(messages[3].content, 'new question');
    });

    test('executeTool create_layer calls repo.saveLayer', () async {
      final provider = FakeLlmProvider([
        ChatResponse(
          toolCalls: [
            ToolCall(
              id: 'call_1',
              name: 'create_layer',
              arguments: jsonEncode({
                'name': 'TestLayer',
                'inputTypes': ['text'],
                'outputTypes': ['json'],
              }),
            ),
          ],
        ),
        const ChatResponse(content: 'Layer created!'),
      ]);

      final service = ChatService(provider: provider, repo: repo);
      await service.handleMessage('Create a layer', []);

      final layers = await repo.layers.listLayers();
      expect(layers, hasLength(1));
      expect(layers.first.name, 'TestLayer');
      expect(layers.first.inputTypes, ['text']);
      expect(layers.first.outputTypes, ['json']);
    });

    test('executeTool create_worker calls repo.saveWorker', () async {
      await repo.layers.saveLayer(
        const LayerDefinition(
          name: 'L1',
          inputTypes: ['text'],
          outputTypes: ['analysis'],
        ),
      );

      final provider = FakeLlmProvider([
        ChatResponse(
          toolCalls: [
            ToolCall(
              id: 'call_1',
              name: 'create_worker',
              arguments: jsonEncode({
                'name': 'W1',
                'layerName': 'L1',
                'systemPrompt': 'You are a helpful assistant.',
              }),
            ),
          ],
        ),
        const ChatResponse(content: 'Worker created!'),
      ]);

      final service = ChatService(provider: provider, repo: repo);
      await service.handleMessage('Create a worker', []);

      final workers = await repo.workers.listWorkers();
      expect(workers, hasLength(1));
      expect(workers.first.name, 'W1');
      expect(workers.first.layerName, 'L1');
    });

    test('executeTool delete_layer calls repo.deleteLayer', () async {
      await repo.layers.saveLayer(
        const LayerDefinition(
          name: 'ToDelete',
          inputTypes: ['text'],
          outputTypes: [],
        ),
      );

      final provider = FakeLlmProvider([
        ChatResponse(
          toolCalls: [
            ToolCall(
              id: 'call_1',
              name: 'delete_layer',
              arguments: jsonEncode({'name': 'ToDelete'}),
            ),
          ],
        ),
        const ChatResponse(content: 'Layer deleted!'),
      ]);

      final service = ChatService(provider: provider, repo: repo);
      await service.handleMessage('Delete the layer', []);

      final layers = await repo.layers.listLayers();
      expect(layers, isEmpty);
    });

    test('executeTool list_layers returns formatted result', () async {
      await repo.layers.saveLayer(
        const LayerDefinition(
          name: 'L1',
          inputTypes: ['text'],
          outputTypes: ['json'],
          order: 1,
        ),
      );

      final result = await ToolRegistry.executeTool(
        'list_layers',
        <String, dynamic>{},
        repo,
      );

      final decoded = jsonDecode(result) as Map<String, dynamic>;
      expect(decoded['layers'], isA<List<dynamic>>());
      final layers = (decoded['layers'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(layers, hasLength(1));
      expect(layers.first['name'], 'L1');
    });

    test('executeTool run_thread triggers scheduler', () async {
      await repo.threads.saveThread(
        const ThreadDefinition(
          name: 'T1',
          path: '/tmp/test',
          layerNames: ['L1'],
        ),
      );

      String? triggeredThread;
      final provider = FakeLlmProvider([
        ChatResponse(
          toolCalls: [
            ToolCall(
              id: 'call_1',
              name: 'run_thread',
              arguments: jsonEncode({'name': 'T1'}),
            ),
          ],
        ),
        const ChatResponse(content: 'Thread started!'),
      ]);

      final service = ChatService(
        provider: provider,
        repo: repo,
        onRunThread: (threadName) async {
          triggeredThread = threadName;
          return jsonEncode({'status': 'running', 'thread': threadName});
        },
      );

      await service.handleMessage('Run the thread', []);

      expect(triggeredThread, 'T1');
    });
  });

  group('ToolRegistry new tools', () {
    late AppDatabase db;
    late AppRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = AppRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('update_thread updates path and contextPrompt', () async {
      await repo.threads.saveThread(
        const ThreadDefinition(
          name: 'T1',
          path: '/old/path',
          layerNames: ['L1'],
          contextPrompt: 'old prompt',
        ),
      );

      final result = await ToolRegistry.executeTool('update_thread', {
        'name': 'T1',
        'path': '/new/path',
        'contextPrompt': 'new prompt',
      }, repo);

      final decoded = jsonDecode(result) as Map<String, dynamic>;
      expect(decoded['success'], isTrue);

      final thread = (await repo.threads.listThreads()).first;
      expect(thread.path, '/new/path');
      expect(thread.contextPrompt, 'new prompt');
    });

    test('update_thread returns error for missing thread', () async {
      final result = await ToolRegistry.executeTool('update_thread', {
        'name': 'NonExistent',
        'path': '/new',
      }, repo);

      final decoded = jsonDecode(result) as Map<String, dynamic>;
      expect(decoded['error'], isNotNull);
    });

    test('delete_thread removes thread', () async {
      await repo.threads.saveThread(
        const ThreadDefinition(
          name: 'ToDelete',
          path: '/tmp',
          layerNames: ['L1'],
        ),
      );

      final result = await ToolRegistry.executeTool('delete_thread', {
        'name': 'ToDelete',
      }, repo);

      final decoded = jsonDecode(result) as Map<String, dynamic>;
      expect(decoded['success'], isTrue);
      expect(await repo.threads.listThreads(), isEmpty);
    });

    test('update_layer with layerPrompt', () async {
      await repo.layers.saveLayer(
        const LayerDefinition(
          name: 'L1',
          inputTypes: ['text'],
          outputTypes: ['json'],
        ),
      );

      final result = await ToolRegistry.executeTool('update_layer', {
        'name': 'L1',
        'layerPrompt': 'Always respond in JSON format',
      }, repo);

      final decoded = jsonDecode(result) as Map<String, dynamic>;
      expect(decoded['success'], isTrue);

      final layer = (await repo.layers.listLayers()).first;
      expect(layer.layerPrompt, 'Always respond in JSON format');
    });

    test('update_worker with temperature and maxTokens', () async {
      await repo.workers.saveWorker(
        const WorkerDefinition(
          name: 'W1',
          layerName: 'L1',
          systemPrompt: 'Hello',
          temperature: 0.7,
          maxTokens: 4096,
        ),
      );

      final result = await ToolRegistry.executeTool('update_worker', {
        'name': 'W1',
        'temperature': 0.3,
        'maxTokens': 2048,
      }, repo);

      final decoded = jsonDecode(result) as Map<String, dynamic>;
      expect(decoded['success'], isTrue);

      final worker = (await repo.workers.listWorkers()).first;
      expect(worker.temperature, 0.3);
      expect(worker.maxTokens, 2048);
    });

    test('update_worker with layerName reassigns worker', () async {
      await repo.layers.saveLayer(
        const LayerDefinition(
          name: 'L1',
          inputTypes: ['text'],
          outputTypes: [],
        ),
      );
      await repo.layers.saveLayer(
        const LayerDefinition(
          name: 'L2',
          inputTypes: ['text'],
          outputTypes: [],
        ),
      );
      await repo.workers.saveWorker(
        const WorkerDefinition(
          name: 'W1',
          layerName: 'L1',
          systemPrompt: 'Hello',
        ),
      );

      final result = await ToolRegistry.executeTool('update_worker', {
        'name': 'W1',
        'layerName': 'L2',
      }, repo);

      final decoded = jsonDecode(result) as Map<String, dynamic>;
      expect(decoded['success'], isTrue);

      final worker = (await repo.workers.listWorkers()).first;
      expect(worker.layerName, 'L2');
    });

    test('assign_worker adds worker to layer', () async {
      await repo.layers.saveLayer(
        const LayerDefinition(
          name: 'L1',
          inputTypes: ['text'],
          outputTypes: ['json'],
        ),
      );
      await repo.workers.saveWorker(
        const WorkerDefinition(
          name: 'W1',
          layerName: '',
          systemPrompt: 'do work',
        ),
      );

      final result = await ToolRegistry.executeTool('assign_worker', {
        'workerName': 'W1',
        'layerName': 'L1',
      }, repo);

      final decoded = jsonDecode(result) as Map<String, dynamic>;
      expect(decoded['success'], isTrue);

      final worker = await repo.workers.getWorker('W1');
      expect(worker!.layerName, 'L1');
    });

    test('assign_worker prevents duplicate assignment', () async {
      await repo.layers.saveLayer(
        const LayerDefinition(
          name: 'L1',
          inputTypes: ['text'],
          outputTypes: ['json'],
        ),
      );
      await repo.workers.saveWorker(
        const WorkerDefinition(
          name: 'W1',
          layerName: 'L1',
          systemPrompt: 'do work',
        ),
      );

      final result = await ToolRegistry.executeTool('assign_worker', {
        'workerName': 'W1',
        'layerName': 'L1',
      }, repo);

      final decoded = jsonDecode(result) as Map<String, dynamic>;
      expect(decoded['error'], isNotNull);
    });

    test('unassign_worker removes worker from layer', () async {
      await repo.layers.saveLayer(
        const LayerDefinition(
          name: 'L1',
          inputTypes: ['text'],
          outputTypes: ['json'],
        ),
      );
      await repo.workers.saveWorker(
        const WorkerDefinition(
          name: 'W1',
          layerName: 'L1',
          systemPrompt: 'do work',
        ),
      );
      await repo.workers.saveWorker(
        const WorkerDefinition(
          name: 'W2',
          layerName: 'L1',
          systemPrompt: 'do work',
        ),
      );

      final result = await ToolRegistry.executeTool('unassign_worker', {
        'workerName': 'W1',
        'layerName': 'L1',
      }, repo);

      final decoded = jsonDecode(result) as Map<String, dynamic>;
      expect(decoded['success'], isTrue);

      final worker = await repo.workers.getWorker('W1');
      expect(worker!.layerName, '');
    });

    test('list_logs returns empty list', () async {
      final result = await ToolRegistry.executeTool(
        'list_logs',
        <String, dynamic>{},
        repo,
      );

      final decoded = jsonDecode(result) as Map<String, dynamic>;
      expect(decoded['logs'], isA<List<dynamic>>());
      expect(decoded['logs'] as List<dynamic>, isEmpty);
    });

    test('list_tasks returns empty list', () async {
      final result = await ToolRegistry.executeTool(
        'list_tasks',
        <String, dynamic>{},
        repo,
      );

      final decoded = jsonDecode(result) as Map<String, dynamic>;
      expect(decoded['tasks'], isA<List<dynamic>>());
      expect(decoded['count'], 0);
    });

    test('get_queue_status returns summary', () async {
      final result = await ToolRegistry.executeTool(
        'get_queue_status',
        <String, dynamic>{},
        repo,
      );

      final decoded = jsonDecode(result) as Map<String, dynamic>;
      expect(decoded['queueSize'], isA<int>());
      expect(decoded['layers'], 0);
      expect(decoded['workers'], 0);
      expect(decoded['threads'], 0);
    });

    test('switch_provider switches active provider', () async {
      await repo.settings.saveSettings(
        const ProviderSettings(
          configs: {
            ProviderType.openAI: OpenAIConfig(apiKey: 'test-key'),
            ProviderType.anthropic: AnthropicConfig(apiKey: 'test-key'),
          },
        ),
      );

      final result = await ToolRegistry.executeTool('switch_provider', {
        'provider': 'anthropic',
      }, repo);

      final decoded = jsonDecode(result) as Map<String, dynamic>;
      expect(decoded['success'], isTrue);
      expect(decoded['activeProvider'], 'anthropic');

      final settings = await repo.settings.getSettings();
      expect(settings.activeProvider, ProviderType.anthropic);
    });

    test('switch_provider rejects unconfigured provider', () async {
      await repo.settings.saveSettings(
        const ProviderSettings(
          configs: {
            ProviderType.openAI: OpenAIConfig(apiKey: 'test-key'),
            ProviderType.anthropic: AnthropicConfig(),
          },
        ),
      );

      final result = await ToolRegistry.executeTool('switch_provider', {
        'provider': 'anthropic',
      }, repo);

      final decoded = jsonDecode(result) as Map<String, dynamic>;
      expect(decoded['error'], isNotNull);
    });

    test('switch_provider rejects unknown provider', () async {
      final result = await ToolRegistry.executeTool('switch_provider', {
        'provider': 'unknown',
      }, repo);

      final decoded = jsonDecode(result) as Map<String, dynamic>;
      expect(decoded['error'], isNotNull);
    });

    test('rename_conversation updates title', () async {
      final conv = ChatConversation.create('Old Title');
      await repo.chat.saveConversation(conv);

      final result = await ToolRegistry.executeTool('rename_conversation', {
        'conversationId': conv.id,
        'title': 'New Title',
      }, repo);

      final decoded = jsonDecode(result) as Map<String, dynamic>;
      expect(decoded['success'], isTrue);

      final convs = await repo.chat.listConversations();
      expect(convs.first.title, 'New Title');
    });

    test(
      'rename_conversation returns error for missing conversation',
      () async {
        final result = await ToolRegistry.executeTool('rename_conversation', {
          'conversationId': 'nonexistent-id',
          'title': 'New Title',
        }, repo);

        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], isNotNull);
      },
    );

    test('search_messages finds messages by keyword', () async {
      final conv = ChatConversation.create('Test');
      await repo.chat.saveConversation(conv);

      await repo.chat.saveMessage(
        ChatMessage.create(
          conversationId: conv.id,
          role: 'user',
          content: 'Hello world',
        ),
      );
      await repo.chat.saveMessage(
        ChatMessage.create(
          conversationId: conv.id,
          role: 'assistant',
          content: 'Hi there!',
        ),
      );
      await repo.chat.saveMessage(
        ChatMessage.create(
          conversationId: conv.id,
          role: 'user',
          content: 'Another message about Flutter',
        ),
      );

      final result = await ToolRegistry.executeTool('search_messages', {
        'query': 'Hello',
      }, repo);

      final decoded = jsonDecode(result) as Map<String, dynamic>;
      expect(decoded['messages'], isA<List<dynamic>>());
      final messages = decoded['messages'] as List<dynamic>;
      expect(messages, hasLength(1));
      expect(
        (messages.first as Map<String, dynamic>)['content'],
        contains('Hello'),
      );
    });

    test('search_messages filters by conversationId', () async {
      final conv1 = ChatConversation.create('Conv1');
      final conv2 = ChatConversation.create('Conv2');
      await repo.chat.saveConversation(conv1);
      await repo.chat.saveConversation(conv2);

      await repo.chat.saveMessage(
        ChatMessage.create(
          conversationId: conv1.id,
          role: 'user',
          content: 'Hello from conv1',
        ),
      );
      await repo.chat.saveMessage(
        ChatMessage.create(
          conversationId: conv2.id,
          role: 'user',
          content: 'Hello from conv2',
        ),
      );

      final result = await ToolRegistry.executeTool('search_messages', {
        'query': 'Hello',
        'conversationId': conv1.id,
      }, repo);

      final decoded = jsonDecode(result) as Map<String, dynamic>;
      final messages = decoded['messages'] as List<dynamic>;
      expect(messages, hasLength(1));
      expect(
        (messages.first as Map<String, dynamic>)['conversationId'],
        conv1.id,
      );
    });

    test('search_messages respects limit', () async {
      final conv = ChatConversation.create('Test');
      await repo.chat.saveConversation(conv);

      for (var i = 0; i < 5; i++) {
        await repo.chat.saveMessage(
          ChatMessage.create(
            conversationId: conv.id,
            role: 'user',
            content: 'Hello message $i',
          ),
        );
      }

      final result = await ToolRegistry.executeTool('search_messages', {
        'query': 'Hello',
        'limit': 2,
      }, repo);

      final decoded = jsonDecode(result) as Map<String, dynamic>;
      final messages = decoded['messages'] as List;
      expect(messages, hasLength(2));
    });

    test('search_messages returns empty for no matches', () async {
      final result = await ToolRegistry.executeTool('search_messages', {
        'query': 'nonexistent',
      }, repo);

      final decoded = jsonDecode(result) as Map<String, dynamic>;
      expect(decoded['messages'], isEmpty);
    });

    test('clear_conversation deletes all messages', () async {
      final conv = ChatConversation.create('Test');
      await repo.chat.saveConversation(conv);

      await repo.chat.saveMessage(
        ChatMessage.create(
          conversationId: conv.id,
          role: 'user',
          content: 'Message 1',
        ),
      );
      await repo.chat.saveMessage(
        ChatMessage.create(
          conversationId: conv.id,
          role: 'assistant',
          content: 'Message 2',
        ),
      );

      final result = await ToolRegistry.executeTool('clear_conversation', {
        'conversationId': conv.id,
      }, repo);

      final decoded = jsonDecode(result) as Map<String, dynamic>;
      expect(decoded['success'], isTrue);

      final messages = await repo.chat.listMessages(conv.id);
      expect(messages, isEmpty);
    });

    test('export_conversation returns markdown', () async {
      final conv = ChatConversation.create('My Chat');
      await repo.chat.saveConversation(conv);

      await repo.chat.saveMessage(
        ChatMessage.create(
          conversationId: conv.id,
          role: 'user',
          content: 'Hello!',
        ),
      );
      await repo.chat.saveMessage(
        ChatMessage.create(
          conversationId: conv.id,
          role: 'assistant',
          content: 'Hi there!',
        ),
      );

      final result = await ToolRegistry.executeTool('export_conversation', {
        'conversationId': conv.id,
      }, repo);

      final decoded = jsonDecode(result) as Map<String, dynamic>;
      expect(decoded['markdown'], isA<String>());
      final md = decoded['markdown'] as String;
      expect(md, contains('My Chat'));
      expect(md, contains('Hello!'));
      expect(md, contains('Hi there!'));
    });

    test(
      'export_conversation returns error for missing conversation',
      () async {
        final result = await ToolRegistry.executeTool('export_conversation', {
          'conversationId': 'nonexistent-id',
        }, repo);

        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], isNotNull);
      },
    );

    test('get_worker_details returns full worker info', () async {
      await repo.layers.saveLayer(
        const LayerDefinition(
          name: 'L1',
          inputTypes: ['text'],
          outputTypes: ['json'],
        ),
      );
      await repo.workers.saveWorker(
        const WorkerDefinition(
          name: 'W1',
          layerName: 'L1',
          systemPrompt: 'You are a helper',
          model: 'gpt-4',
          temperature: 0.7,
          maxTokens: 4096,
        ),
      );
      await repo.logs.logExecution(
        taskId: 'task1',
        workerName: 'W1',
        status: 'completed',
        message: 'Task done',
      );
      await repo.logs.logExecution(
        taskId: 'task2',
        workerName: 'W1',
        status: 'completed',
        message: 'Another task done',
      );

      final result = await ToolRegistry.executeTool('get_worker_details', {
        'name': 'W1',
      }, repo);

      final decoded = jsonDecode(result) as Map<String, dynamic>;
      expect(decoded['name'], 'W1');
      expect(decoded['layerName'], 'L1');
      expect(decoded['systemPrompt'], 'You are a helper');
      expect(decoded['model'], 'gpt-4');
      expect(decoded['temperature'], 0.7);
      expect(decoded['maxTokens'], 4096);
      expect(decoded['recentLogs'], isA<List<dynamic>>());
      expect(decoded['recentLogs'] as List<dynamic>, isNotEmpty);
    });

    test('get_worker_details returns error for missing worker', () async {
      final result = await ToolRegistry.executeTool('get_worker_details', {
        'name': 'NonExistent',
      }, repo);

      final decoded = jsonDecode(result) as Map<String, dynamic>;
      expect(decoded['error'], isNotNull);
    });
  });
}
