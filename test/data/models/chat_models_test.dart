import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/models/app_models.dart';

void main() {
  group('ChatConversation', () {
    test('create factory generates UUID, sets timestamps, and keeps title', () {
      final conv = ChatConversation.create('Test Chat');

      expect(conv.id, isNotEmpty);
      expect(conv.title, 'Test Chat');
      expect(conv.createdAt, greaterThan(0));
      expect(conv.updatedAt, greaterThan(0));
      expect(conv.createdAt, conv.updatedAt);
    });

    test('create factory generates unique ids', () {
      final a = ChatConversation.create('A');
      final b = ChatConversation.create('B');

      expect(a.id, isNot(equals(b.id)));
    });

    test('copyWith overrides only specified fields', () {
      final original = ChatConversation.create('Original');
      final copied = original.copyWith(title: 'Updated', updatedAt: 0);

      expect(copied.id, original.id);
      expect(copied.title, 'Updated');
      expect(copied.createdAt, original.createdAt);
      expect(copied.updatedAt, 0);
    });

    test('copyWith preserves fields when no overrides given', () {
      final original = ChatConversation.create('Keep');
      final copied = original.copyWith();

      expect(copied.id, original.id);
      expect(copied.title, original.title);
      expect(copied.createdAt, original.createdAt);
      expect(copied.updatedAt, original.updatedAt);
    });

    test('equality based on id', () {
      final a = ChatConversation.create('First');
      final b = a.copyWith(title: 'Second');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('inequality for different ids', () {
      final a = ChatConversation.create('A');
      final b = ChatConversation.create('B');

      expect(a, isNot(equals(b)));
    });

    test('can be used in Set deduplication', () {
      final a = ChatConversation.create('Chat');
      final set = <ChatConversation>{a, a.copyWith(title: 'Updated')};

      expect(set, hasLength(1));
    });

    test('const constructor holds all fields', () {
      const conv = ChatConversation(
        id: 'fixed-id',
        title: 'Fixed',
        createdAt: 1000,
        updatedAt: 2000,
      );

      expect(conv.id, 'fixed-id');
      expect(conv.title, 'Fixed');
      expect(conv.createdAt, 1000);
      expect(conv.updatedAt, 2000);
    });
  });

  group('ChatMessage', () {
    test('create factory generates UUID, sets timestamp, and keeps fields', () {
      final msg = ChatMessage.create(
        conversationId: 'conv-1',
        role: 'user',
        content: 'Hello, world!',
      );

      expect(msg.id, isNotEmpty);
      expect(msg.conversationId, 'conv-1');
      expect(msg.role, 'user');
      expect(msg.content, 'Hello, world!');
      expect(msg.toolName, isNull);
      expect(msg.toolCallId, isNull);
      expect(msg.createdAt, greaterThan(0));
    });

    test('create factory generates unique ids', () {
      final a = ChatMessage.create(
        conversationId: 'c',
        role: 'user',
        content: 'a',
      );
      final b = ChatMessage.create(
        conversationId: 'c',
        role: 'user',
        content: 'b',
      );

      expect(a.id, isNot(equals(b.id)));
    });

    test('create factory with tool fields', () {
      final msg = ChatMessage.create(
        conversationId: 'conv-2',
        role: 'tool',
        content: '{"result": 42}',
        toolName: 'calculator',
        toolCallId: 'call-abc',
      );

      expect(msg.toolName, 'calculator');
      expect(msg.toolCallId, 'call-abc');
      expect(msg.role, 'tool');
    });

    test('copyWith overrides only specified fields', () {
      final original = ChatMessage.create(
        conversationId: 'c1',
        role: 'user',
        content: 'hi',
      );
      final copied = original.copyWith(content: 'hello', role: 'assistant');

      expect(copied.id, original.id);
      expect(copied.conversationId, original.conversationId);
      expect(copied.content, 'hello');
      expect(copied.role, 'assistant');
      expect(copied.createdAt, original.createdAt);
    });

    test('copyWith preserves fields when no overrides given', () {
      final original = ChatMessage.create(
        conversationId: 'c1',
        role: 'user',
        content: 'keep',
      );
      final copied = original.copyWith();

      expect(copied.id, original.id);
      expect(copied.conversationId, original.conversationId);
      expect(copied.role, original.role);
      expect(copied.content, original.content);
      expect(copied.toolName, original.toolName);
      expect(copied.toolCallId, original.toolCallId);
      expect(copied.createdAt, original.createdAt);
    });

    test('copyWith can set tool fields', () {
      final original = ChatMessage.create(
        conversationId: 'c1',
        role: 'assistant',
        content: '',
      );
      final copied = original.copyWith(
        toolName: 'search',
        toolCallId: 'call-123',
      );

      expect(copied.toolName, 'search');
      expect(copied.toolCallId, 'call-123');
      expect(copied.id, original.id);
    });

    test('equality based on id', () {
      final a = ChatMessage.create(
        conversationId: 'c1',
        role: 'user',
        content: 'original',
      );
      final b = a.copyWith(content: 'changed');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('inequality for different ids', () {
      final a = ChatMessage.create(
        conversationId: 'c1',
        role: 'user',
        content: 'same',
      );
      final b = ChatMessage.create(
        conversationId: 'c1',
        role: 'user',
        content: 'same',
      );

      expect(a, isNot(equals(b)));
    });

    test('can be used in Set deduplication', () {
      final a = ChatMessage.create(
        conversationId: 'c1',
        role: 'user',
        content: 'msg',
      );
      final set = <ChatMessage>{a, a.copyWith(content: 'updated')};

      expect(set, hasLength(1));
    });

    test('const constructor holds all fields', () {
      const msg = ChatMessage(
        id: 'fixed-msg-id',
        conversationId: 'conv-id',
        role: 'system',
        content: 'You are helpful.',
        createdAt: 3000,
      );

      expect(msg.id, 'fixed-msg-id');
      expect(msg.conversationId, 'conv-id');
      expect(msg.role, 'system');
      expect(msg.content, 'You are helpful.');
      expect(msg.toolName, isNull);
      expect(msg.toolCallId, isNull);
      expect(msg.createdAt, 3000);
    });
  });

  group('ChatMessage role values', () {
    test('supports user role', () {
      final msg = ChatMessage.create(
        conversationId: 'c',
        role: 'user',
        content: 'hi',
      );
      expect(msg.role, 'user');
    });

    test('supports assistant role', () {
      final msg = ChatMessage.create(
        conversationId: 'c',
        role: 'assistant',
        content: 'hello',
      );
      expect(msg.role, 'assistant');
    });

    test('supports system role', () {
      final msg = ChatMessage.create(
        conversationId: 'c',
        role: 'system',
        content: 'instruction',
      );
      expect(msg.role, 'system');
    });

    test('supports tool role', () {
      final msg = ChatMessage.create(
        conversationId: 'c',
        role: 'tool',
        content: 'result',
      );
      expect(msg.role, 'tool');
    });
  });
}
