import 'package:drift/drift.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/models/chat_models.dart';

class ChatRepository {
  ChatRepository(this._db);
  final AppDatabase _db;

  Future<void> saveConversation(ChatConversation conv) {
    return _db.saveChatConversation(
      ChatConversationsCompanion.insert(
        id: conv.id,
        title: conv.title,
        createdAt: conv.createdAt,
        updatedAt: conv.updatedAt,
      ),
    );
  }

  Future<List<ChatConversation>> listConversations() async {
    final rows = await _db.listChatConversations();
    return rows
        .map(
          (r) => ChatConversation(
            id: r.id,
            title: r.title,
            createdAt: r.createdAt,
            updatedAt: r.updatedAt,
          ),
        )
        .toList();
  }

  Stream<List<ChatConversation>> watchConversations() {
    return _db.watchChatConversations().map(
      (rows) => rows
          .map(
            (r) => ChatConversation(
              id: r.id,
              title: r.title,
              createdAt: r.createdAt,
              updatedAt: r.updatedAt,
            ),
          )
          .toList(),
    );
  }

  Future<void> deleteConversation(String id) async {
    await _db.deleteChatMessagesByConversation(id);
    await _db.deleteChatConversation(id);
  }

  Future<void> saveMessage(ChatMessage msg) {
    return _db.saveChatMessage(
      ChatMessagesCompanion.insert(
        id: msg.id,
        conversationId: msg.conversationId,
        role: msg.role,
        content: msg.content,
        toolName: Value(msg.toolName),
        toolCallId: Value(msg.toolCallId),
        createdAt: msg.createdAt,
      ),
    );
  }

  Future<List<ChatMessage>> listMessages(String conversationId) async {
    final rows = await _db.listChatMessages(conversationId);
    return rows
        .map(
          (r) => ChatMessage(
            id: r.id,
            conversationId: r.conversationId,
            role: r.role,
            content: r.content,
            toolName: r.toolName,
            toolCallId: r.toolCallId,
            createdAt: r.createdAt,
          ),
        )
        .toList();
  }

  Stream<List<ChatMessage>> watchMessages(String conversationId) {
    return _db
        .watchChatMessages(conversationId)
        .map(
          (rows) => rows
              .map(
                (r) => ChatMessage(
                  id: r.id,
                  conversationId: r.conversationId,
                  role: r.role,
                  content: r.content,
                  toolName: r.toolName,
                  toolCallId: r.toolCallId,
                  createdAt: r.createdAt,
                ),
              )
              .toList(),
        );
  }

  Future<void> deleteMessage(String id) {
    return _db.deleteChatMessage(id);
  }
}
