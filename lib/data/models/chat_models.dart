// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes
import 'package:uuid/uuid.dart';

class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatConversation.create(String title) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return ChatConversation(
      id: const Uuid().v4(),
      title: title,
      createdAt: now,
      updatedAt: now,
    );
  }

  final String id;
  final String title;
  final int createdAt;
  final int updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ChatConversation && id == other.id;

  @override
  int get hashCode => id.hashCode;

  ChatConversation copyWith({String? title, int? updatedAt}) {
    return ChatConversation(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.toolName,
    this.toolCallId,
  });

  factory ChatMessage.create({
    required String conversationId,
    required String role,
    required String content,
    String? toolName,
    String? toolCallId,
  }) {
    return ChatMessage(
      id: const Uuid().v4(),
      conversationId: conversationId,
      role: role,
      content: content,
      toolName: toolName,
      toolCallId: toolCallId,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  final String id;
  final String conversationId;
  final String role;
  final String content;
  final String? toolName;
  final String? toolCallId;
  final int createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ChatMessage && id == other.id;

  @override
  int get hashCode => id.hashCode;

  ChatMessage copyWith({
    String? role,
    String? content,
    String? toolName,
    String? toolCallId,
  }) {
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      role: role ?? this.role,
      content: content ?? this.content,
      toolName: toolName ?? this.toolName,
      toolCallId: toolCallId ?? this.toolCallId,
      createdAt: createdAt,
    );
  }
}
