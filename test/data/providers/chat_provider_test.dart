import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/providers/chat_provider.dart';
import 'package:gyeol/data/providers/core_providers.dart';
import 'package:gyeol/data/providers/settings_provider.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('ConversationsNotifier', () {
    test('build returns empty list when no conversations', () async {
      final convs = await container.read(conversationsProvider.future);
      expect(convs, isEmpty);
    });

    test('createConversation persists and returns conversation', () async {
      final notifier = container.read(conversationsProvider.notifier);
      final conv = await notifier.createConversation('Test Chat');

      expect(conv.title, 'Test Chat');
      expect(conv.id, isNotEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final convs = await container.read(conversationsProvider.future);
      expect(convs, hasLength(1));
      expect(convs.first.title, 'Test Chat');
    });

    test('createConversation generates unique ids', () async {
      final notifier = container.read(conversationsProvider.notifier);
      final conv1 = await notifier.createConversation('A');
      final conv2 = await notifier.createConversation('B');

      expect(conv1.id, isNot(equals(conv2.id)));
    });

    test('deleteConversation removes conversation', () async {
      final notifier = container.read(conversationsProvider.notifier);
      final conv = await notifier.createConversation('To Delete');

      await Future<void>.delayed(const Duration(milliseconds: 50));
      var convs = await container.read(conversationsProvider.future);
      expect(convs, hasLength(1));

      await notifier.deleteConversation(conv.id);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      convs = await container.read(conversationsProvider.future);
      expect(convs, isEmpty);
    });

    test('updateConversation saves changes', () async {
      final notifier = container.read(conversationsProvider.notifier);
      final conv = await notifier.createConversation('Original');

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await notifier.updateConversation(conv.copyWith(title: 'Updated'));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final convs = await container.read(conversationsProvider.future);
      expect(convs, hasLength(1));
      expect(convs.first.title, 'Updated');
    });

    test('renameConversation updates title', () async {
      final notifier = container.read(conversationsProvider.notifier);
      final conv = await notifier.createConversation('Old Title');

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await notifier.renameConversation(conv.id, 'New Title');

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final convs = await container.read(conversationsProvider.future);
      expect(convs, hasLength(1));
      expect(convs.first.title, 'New Title');
    });

    test('clearConversationMessages removes all messages', () async {
      final repo = container.read(repositoryProvider);
      final notifier = container.read(conversationsProvider.notifier);
      final conv = await notifier.createConversation('Chat');

      await repo.chat.saveMessage(
        ChatMessage.create(
          conversationId: conv.id,
          role: 'user',
          content: 'Hello',
        ),
      );
      await repo.chat.saveMessage(
        ChatMessage.create(
          conversationId: conv.id,
          role: 'assistant',
          content: 'Hi!',
        ),
      );

      var msgs = await repo.chat.listMessages(conv.id);
      expect(msgs, hasLength(2));

      await notifier.clearConversationMessages(conv.id);

      msgs = await repo.chat.listMessages(conv.id);
      expect(msgs, isEmpty);
    });

    test('multiple conversations persist independently', () async {
      final notifier = container.read(conversationsProvider.notifier);
      await notifier.createConversation('First');
      await notifier.createConversation('Second');
      await notifier.createConversation('Third');

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final convs = await container.read(conversationsProvider.future);
      expect(convs, hasLength(3));
      final titles = convs.map((c) => c.title).toList();
      expect(titles, containsAll(['First', 'Second', 'Third']));
    });
  });

  group('chatMessagesProvider', () {
    test('returns empty list for conversation with no messages', () async {
      final notifier = container.read(conversationsProvider.notifier);
      final conv = await notifier.createConversation('Empty');

      final msgs = await container.read(chatMessagesProvider(conv.id).future);
      expect(msgs, isEmpty);
    });

    test('returns persisted messages for conversation', () async {
      final repo = container.read(repositoryProvider);
      final notifier = container.read(conversationsProvider.notifier);
      final conv = await notifier.createConversation('Chat');

      await repo.chat.saveMessage(
        ChatMessage.create(
          conversationId: conv.id,
          role: 'user',
          content: 'Hello',
        ),
      );
      await repo.chat.saveMessage(
        ChatMessage.create(
          conversationId: conv.id,
          role: 'assistant',
          content: 'World',
        ),
      );

      container.invalidate(chatMessagesProvider(conv.id));
      final msgs = await container.read(chatMessagesProvider(conv.id).future);
      expect(msgs, hasLength(2));
      expect(msgs.any((m) => m.content == 'Hello'), isTrue);
      expect(msgs.any((m) => m.content == 'World'), isTrue);
    });
  });

  group('chatSendingProvider', () {
    test('defaults to false', () {
      final sending = container.read(chatSendingProvider);
      expect(sending, isFalse);
    });

    test('can be set to true', () {
      container.read(chatSendingProvider.notifier).state = true;
      expect(container.read(chatSendingProvider), isTrue);
    });
  });

  group('selectedConversationIdProvider', () {
    test('defaults to null', () {
      final id = container.read(selectedConversationIdProvider);
      expect(id, isNull);
    });

    test('can be set to a conversation id', () {
      container.read(selectedConversationIdProvider.notifier).state = 'abc';
      expect(container.read(selectedConversationIdProvider), 'abc');
    });
  });

  group('chatServiceProvider', () {
    test('provides a ChatService instance', () async {
      final repo = container.read(repositoryProvider);
      await repo.settings.saveSettings(
        const ProviderSettings(
          configs: {ProviderType.openAI: OpenAIConfig(apiKey: 'test-key')},
        ),
      );
      await container.read(settingsProvider.future);

      final service = container.read(chatServiceProvider);
      expect(service, isNotNull);
    });
  });
}
