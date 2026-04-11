import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/repositories/app_repository.dart';

void main() {
  late AppDatabase db;
  late AppRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = AppRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('saveConversation + listConversations', () {
    test('round-trips a ChatConversation', () async {
      final conv = ChatConversation.create('Test Chat');
      await repo.chat.saveConversation(conv);

      final conversations = await repo.chat.listConversations();
      expect(conversations, hasLength(1));
      expect(conversations.first.id, conv.id);
      expect(conversations.first.title, 'Test Chat');
      expect(conversations.first.createdAt, conv.createdAt);
      expect(conversations.first.updatedAt, conv.updatedAt);
    });

    test('returns conversations ordered by updatedAt descending', () async {
      const older = ChatConversation(
        id: 'conv-old',
        title: 'Older',
        createdAt: 1000,
        updatedAt: 1000,
      );
      const newer = ChatConversation(
        id: 'conv-new',
        title: 'Newer',
        createdAt: 2000,
        updatedAt: 2000,
      );
      await repo.chat.saveConversation(older);
      await repo.chat.saveConversation(newer);

      final conversations = await repo.chat.listConversations();
      expect(conversations, hasLength(2));
      expect(conversations.first.id, 'conv-new');
      expect(conversations.last.id, 'conv-old');
    });

    test('upserts conversation with same id', () async {
      final conv = ChatConversation.create('Original');
      await repo.chat.saveConversation(conv);

      final updated = conv.copyWith(title: 'Updated');
      await repo.chat.saveConversation(updated);

      final conversations = await repo.chat.listConversations();
      expect(conversations, hasLength(1));
      expect(conversations.first.title, 'Updated');
      expect(conversations.first.id, conv.id);
    });

    test('returns empty list when no conversations', () async {
      final conversations = await repo.chat.listConversations();
      expect(conversations, isEmpty);
    });
  });

  group('saveMessage + listMessages', () {
    test('round-trips a ChatMessage', () async {
      await repo.chat.saveConversation(
        const ChatConversation(
          id: 'conv-1',
          title: 'Test',
          createdAt: 1000,
          updatedAt: 1000,
        ),
      );
      final msg = ChatMessage.create(
        conversationId: 'conv-1',
        role: 'user',
        content: 'Hello!',
      );
      await repo.chat.saveMessage(msg);

      final messages = await repo.chat.listMessages('conv-1');
      expect(messages, hasLength(1));
      expect(messages.first.id, msg.id);
      expect(messages.first.conversationId, 'conv-1');
      expect(messages.first.role, 'user');
      expect(messages.first.content, 'Hello!');
      expect(messages.first.toolName, isNull);
      expect(messages.first.toolCallId, isNull);
      expect(messages.first.createdAt, msg.createdAt);
    });

    test('filters messages by conversationId', () async {
      await repo.chat.saveConversation(
        const ChatConversation(
          id: 'conv-a',
          title: 'A',
          createdAt: 1000,
          updatedAt: 1000,
        ),
      );
      await repo.chat.saveConversation(
        const ChatConversation(
          id: 'conv-b',
          title: 'B',
          createdAt: 1000,
          updatedAt: 1000,
        ),
      );
      final msgA = ChatMessage.create(
        conversationId: 'conv-a',
        role: 'user',
        content: 'In A',
      );
      final msgB = ChatMessage.create(
        conversationId: 'conv-b',
        role: 'user',
        content: 'In B',
      );
      await repo.chat.saveMessage(msgA);
      await repo.chat.saveMessage(msgB);

      final messagesA = await repo.chat.listMessages('conv-a');
      expect(messagesA, hasLength(1));
      expect(messagesA.first.conversationId, 'conv-a');

      final messagesB = await repo.chat.listMessages('conv-b');
      expect(messagesB, hasLength(1));
      expect(messagesB.first.conversationId, 'conv-b');
    });

    test('returns messages ordered by createdAt ascending', () async {
      await repo.chat.saveConversation(
        const ChatConversation(
          id: 'conv-1',
          title: 'Test',
          createdAt: 1000,
          updatedAt: 1000,
        ),
      );
      const first = ChatMessage(
        id: 'msg-1',
        conversationId: 'conv-1',
        role: 'user',
        content: 'first',
        createdAt: 1000,
      );
      const second = ChatMessage(
        id: 'msg-2',
        conversationId: 'conv-1',
        role: 'assistant',
        content: 'second',
        createdAt: 2000,
      );
      await repo.chat.saveMessage(second);
      await repo.chat.saveMessage(first);

      final messages = await repo.chat.listMessages('conv-1');
      expect(messages, hasLength(2));
      expect(messages.first.id, 'msg-1');
      expect(messages.last.id, 'msg-2');
    });

    test('round-trips tool fields', () async {
      await repo.chat.saveConversation(
        const ChatConversation(
          id: 'conv-1',
          title: 'Test',
          createdAt: 1000,
          updatedAt: 1000,
        ),
      );
      final msg = ChatMessage.create(
        conversationId: 'conv-1',
        role: 'tool',
        content: '{"result": 42}',
        toolName: 'calculator',
        toolCallId: 'call-abc',
      );
      await repo.chat.saveMessage(msg);

      final messages = await repo.chat.listMessages('conv-1');
      expect(messages, hasLength(1));
      expect(messages.first.toolName, 'calculator');
      expect(messages.first.toolCallId, 'call-abc');
    });

    test('returns empty list for non-existent conversation', () async {
      final messages = await repo.chat.listMessages('nonexistent');
      expect(messages, isEmpty);
    });

    test('upserts message with same id', () async {
      await repo.chat.saveConversation(
        const ChatConversation(
          id: 'conv-1',
          title: 'Test',
          createdAt: 1000,
          updatedAt: 1000,
        ),
      );
      final msg = ChatMessage.create(
        conversationId: 'conv-1',
        role: 'user',
        content: 'original',
      );
      await repo.chat.saveMessage(msg);

      final updated = msg.copyWith(content: 'edited');
      await repo.chat.saveMessage(updated);

      final messages = await repo.chat.listMessages('conv-1');
      expect(messages, hasLength(1));
      expect(messages.first.content, 'edited');
    });
  });

  group('deleteConversation', () {
    test('removes conversation', () async {
      final conv = ChatConversation.create('ToDelete');
      await repo.chat.saveConversation(conv);
      expect(await repo.chat.listConversations(), hasLength(1));

      await repo.chat.deleteConversation(conv.id);
      expect(await repo.chat.listConversations(), isEmpty);
    });

    test('cascades and removes associated messages', () async {
      final conv = ChatConversation.create('Cascade');
      await repo.chat.saveConversation(conv);

      final msg1 = ChatMessage.create(
        conversationId: conv.id,
        role: 'user',
        content: 'msg 1',
      );
      final msg2 = ChatMessage.create(
        conversationId: conv.id,
        role: 'assistant',
        content: 'msg 2',
      );
      await repo.chat.saveMessage(msg1);
      await repo.chat.saveMessage(msg2);
      expect(await repo.chat.listMessages(conv.id), hasLength(2));

      await repo.chat.deleteConversation(conv.id);
      expect(await repo.chat.listMessages(conv.id), isEmpty);
    });

    test('does not affect other conversations messages', () async {
      final convA = ChatConversation.create('A');
      final convB = ChatConversation.create('B');
      await repo.chat.saveConversation(convA);
      await repo.chat.saveConversation(convB);

      final msgA = ChatMessage.create(
        conversationId: convA.id,
        role: 'user',
        content: 'in A',
      );
      final msgB = ChatMessage.create(
        conversationId: convB.id,
        role: 'user',
        content: 'in B',
      );
      await repo.chat.saveMessage(msgA);
      await repo.chat.saveMessage(msgB);

      await repo.chat.deleteConversation(convA.id);
      expect(await repo.chat.listMessages(convA.id), isEmpty);
      expect(await repo.chat.listMessages(convB.id), hasLength(1));
    });
  });

  group('deleteMessage', () {
    test('removes a specific message', () async {
      final conv = ChatConversation.create('Conv');
      await repo.chat.saveConversation(conv);

      final msg1 = ChatMessage.create(
        conversationId: conv.id,
        role: 'user',
        content: 'keep',
      );
      final msg2 = ChatMessage.create(
        conversationId: conv.id,
        role: 'assistant',
        content: 'delete me',
      );
      await repo.chat.saveMessage(msg1);
      await repo.chat.saveMessage(msg2);
      expect(await repo.chat.listMessages(conv.id), hasLength(2));

      await repo.chat.deleteMessage(msg2.id);
      final remaining = await repo.chat.listMessages(conv.id);
      expect(remaining, hasLength(1));
      expect(remaining.first.id, msg1.id);
    });

    test('does not affect other messages', () async {
      await repo.chat.saveConversation(
        const ChatConversation(
          id: 'c1',
          title: 'C1',
          createdAt: 1000,
          updatedAt: 1000,
        ),
      );
      final msg1 = ChatMessage.create(
        conversationId: 'c1',
        role: 'user',
        content: 'a',
      );
      final msg2 = ChatMessage.create(
        conversationId: 'c1',
        role: 'user',
        content: 'b',
      );
      await repo.chat.saveMessage(msg1);
      await repo.chat.saveMessage(msg2);

      await repo.chat.deleteMessage(msg1.id);
      final remaining = await repo.chat.listMessages('c1');
      expect(remaining, hasLength(1));
      expect(remaining.first.id, msg2.id);
    });
  });

  group('multiple conversations with messages', () {
    test('isolates messages per conversation', () async {
      final conv1 = ChatConversation.create('Chat 1');
      final conv2 = ChatConversation.create('Chat 2');
      await repo.chat.saveConversation(conv1);
      await repo.chat.saveConversation(conv2);

      for (var i = 0; i < 3; i++) {
        await repo.chat.saveMessage(
          ChatMessage.create(
            conversationId: conv1.id,
            role: i.isEven ? 'user' : 'assistant',
            content: 'conv1 msg $i',
          ),
        );
      }

      for (var i = 0; i < 2; i++) {
        await repo.chat.saveMessage(
          ChatMessage.create(
            conversationId: conv2.id,
            role: i.isEven ? 'user' : 'assistant',
            content: 'conv2 msg $i',
          ),
        );
      }

      final conv1Messages = await repo.chat.listMessages(conv1.id);
      final conv2Messages = await repo.chat.listMessages(conv2.id);
      expect(conv1Messages, hasLength(3));
      expect(conv2Messages, hasLength(2));

      for (final msg in conv1Messages) {
        expect(msg.conversationId, conv1.id);
      }
      for (final msg in conv2Messages) {
        expect(msg.conversationId, conv2.id);
      }
    });

    test('full conversation lifecycle', () async {
      final conv = ChatConversation.create('Lifecycle');
      await repo.chat.saveConversation(conv);

      final userMsg = ChatMessage.create(
        conversationId: conv.id,
        role: 'user',
        content: 'What is 2+2?',
      );
      await repo.chat.saveMessage(userMsg);

      final assistantMsg = ChatMessage.create(
        conversationId: conv.id,
        role: 'assistant',
        content: '4',
      );
      await repo.chat.saveMessage(assistantMsg);

      final messages = await repo.chat.listMessages(conv.id);
      expect(messages, hasLength(2));
      expect(messages.first.role, 'user');
      expect(messages.last.role, 'assistant');

      final updatedConv = conv.copyWith(
        title: 'Lifecycle (updated)',
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await repo.chat.saveConversation(updatedConv);

      final conversations = await repo.chat.listConversations();
      expect(conversations.first.title, 'Lifecycle (updated)');

      await repo.chat.deleteConversation(conv.id);
      expect(await repo.chat.listConversations(), isEmpty);
      expect(await repo.chat.listMessages(conv.id), isEmpty);
    });
  });
}
