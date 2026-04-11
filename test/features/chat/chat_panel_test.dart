import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/providers/app_providers.dart';
import 'package:gyeol/features/chat/chat_panel.dart';

void main() {
  Future<void> pumpChatPanel(
    WidgetTester tester, {
    List<ChatConversation>? conversations,
    String? selectedConvId,
    List<ChatMessage>? messages,
    bool isSending = false,
  }) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    final convs = conversations ?? [];
    final convId = selectedConvId;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            () => _FakeSettingsNotifier(const ProviderSettings()),
          ),
          conversationsProvider.overrideWith(
            () => _FakeConversationsNotifier(convs),
          ),
          chatSendingProvider.overrideWith((ref) => isSending),
          selectedConversationIdProvider.overrideWith((ref) => convId),
          if (convId != null)
            chatMessagesProvider(
              convId,
            ).overrideWith((ref) async => messages ?? []),
        ],
        child: const MaterialApp(home: Scaffold(body: ChatPanel())),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  group('ChatPanel', () {
    testWidgets('renders welcome greeting when no conversations exist', (
      tester,
    ) async {
      await pumpChatPanel(tester);
      expect(find.text('Gyeol AI 어시스턴트에 오신 것을 환영합니다'), findsOneWidget);
    });

    testWidgets('renders text input field with hint', (tester) async {
      await pumpChatPanel(tester);
      expect(
        find.text('Type a message... (Shift+Enter for new line)'),
        findsOneWidget,
      );
    });

    testWidgets('renders New conversation button when unselected', (
      tester,
    ) async {
      await pumpChatPanel(tester);
      expect(
        find.widgetWithText(OutlinedButton, 'New conversation'),
        findsOneWidget,
      );
    });

    testWidgets('renders 시작 텍스트 when conversation has no messages', (
      tester,
    ) async {
      const convId = 'conv-1';
      await pumpChatPanel(
        tester,
        conversations: [
          const ChatConversation(
            id: convId,
            title: 'Test Chat',
            createdAt: 1000,
            updatedAt: 1000,
          ),
        ],
        selectedConvId: convId,
        messages: [],
      );
      expect(find.text('메시지를 입력하여 대화를 시작하세요'), findsOneWidget);
    });

    testWidgets('renders user and assistant messages', (tester) async {
      const convId = 'conv-2';
      await pumpChatPanel(
        tester,
        conversations: [
          const ChatConversation(
            id: convId,
            title: 'Chat with messages',
            createdAt: 1000,
            updatedAt: 1000,
          ),
        ],
        selectedConvId: convId,
        messages: [
          const ChatMessage(
            id: 'm1',
            conversationId: convId,
            role: 'user',
            content: 'Hello AI',
            createdAt: 1000,
          ),
          const ChatMessage(
            id: 'm2',
            conversationId: convId,
            role: 'assistant',
            content: 'Hello! How can I help?',
            createdAt: 2000,
          ),
        ],
      );
      expect(find.text('Hello AI'), findsOneWidget);
      expect(find.text('Hello! How can I help?'), findsOneWidget);
    });

    testWidgets('renders tool message with tool name', (tester) async {
      const convId = 'conv-3';
      await pumpChatPanel(
        tester,
        conversations: [
          const ChatConversation(
            id: convId,
            title: 'Tool Chat',
            createdAt: 1000,
            updatedAt: 1000,
          ),
        ],
        selectedConvId: convId,
        messages: [
          const ChatMessage(
            id: 'm1',
            conversationId: convId,
            role: 'tool',
            content: '{"success": true, "message": "Layer created"}',
            toolName: 'create_layer',
            createdAt: 1000,
          ),
        ],
      );
      expect(find.text('create_layer'), findsOneWidget);
      expect(find.text('Layer created'), findsOneWidget);
    });

    testWidgets('shows send button when not sending', (tester) async {
      await pumpChatPanel(tester);
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    });

    testWidgets('shows disabled send button when sending', (tester) async {
      await pumpChatPanel(tester, isSending: true);
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    });

    testWidgets('shows conversation dropdown when conversations exist', (
      tester,
    ) async {
      await pumpChatPanel(
        tester,
        conversations: [
          const ChatConversation(
            id: 'c1',
            title: 'First Chat',
            createdAt: 1000,
            updatedAt: 1000,
          ),
        ],
        selectedConvId: 'c1',
        messages: [],
      );
      expect(find.text('First Chat'), findsOneWidget);
    });

    testWidgets('renders present_choices tool as choice card', (tester) async {
      const convId = 'conv-4';
      await pumpChatPanel(
        tester,
        conversations: [
          const ChatConversation(
            id: convId,
            title: 'Choices',
            createdAt: 1000,
            updatedAt: 1000,
          ),
        ],
        selectedConvId: convId,
        messages: [
          const ChatMessage(
            id: 'm1',
            conversationId: convId,
            role: 'tool',
            content: '{"title":"Select option","options":["A","B"]}',
            toolName: 'present_choices',
            createdAt: 1000,
          ),
        ],
      );
      expect(find.text('Select option'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('renders confirm_action tool as confirm card', (tester) async {
      const convId = 'conv-5';
      await pumpChatPanel(
        tester,
        conversations: [
          const ChatConversation(
            id: convId,
            title: 'Confirm',
            createdAt: 1000,
            updatedAt: 1000,
          ),
        ],
        selectedConvId: convId,
        messages: [
          const ChatMessage(
            id: 'm1',
            conversationId: convId,
            role: 'tool',
            content:
                '{"title":"Confirm action", '
                '"description":"Delete layer?", '
                '"action":"delete"}',
            toolName: 'confirm_action',
            createdAt: 1000,
          ),
        ],
      );
      expect(find.text('Confirm action'), findsOneWidget);
      expect(find.text('Delete layer?'), findsOneWidget);
      expect(find.text('승인'), findsOneWidget);
      expect(find.text('거부'), findsOneWidget);
    });

    testWidgets('renders suggested prompt chips in welcome state', (
      tester,
    ) async {
      await pumpChatPanel(tester);
      expect(find.text('도움이 되는 레이어 만들기'), findsOneWidget);
      expect(find.text('사용 가능한 모델 보기'), findsOneWidget);
      expect(find.text('시스템 상태 확인'), findsOneWidget);
    });

    testWidgets('renders toolbar action buttons when conversation selected', (
      tester,
    ) async {
      const convId = 'c1';
      await pumpChatPanel(
        tester,
        conversations: [
          const ChatConversation(
            id: convId,
            title: 'Test',
            createdAt: 1000,
            updatedAt: 1000,
          ),
        ],
        selectedConvId: convId,
        messages: [],
      );
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byIcon(Icons.save_alt), findsOneWidget);
      expect(find.byIcon(Icons.delete_sweep), findsOneWidget);
    });
  });
}

class _FakeSettingsNotifier extends SettingsNotifier {
  _FakeSettingsNotifier(this._settings);
  final ProviderSettings _settings;

  @override
  Future<ProviderSettings> build() async => _settings;
}

class _FakeConversationsNotifier extends ConversationsNotifier {
  _FakeConversationsNotifier(this._conversations);
  final List<ChatConversation> _conversations;

  @override
  Future<List<ChatConversation>> build() async => _conversations;
}
