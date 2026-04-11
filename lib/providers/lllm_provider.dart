class ChatMessageForApi {
  const ChatMessageForApi({
    required this.role,
    this.content,
    this.toolCalls,
    this.toolCallId,
  });
  final String role;
  final String? content;
  final List<ToolCall>? toolCalls;
  final String? toolCallId;
}

class ChatResponse {
  const ChatResponse({this.content, this.toolCalls});
  final String? content;
  final List<ToolCall>? toolCalls;
}

class ChatStreamDelta {
  const ChatStreamDelta({this.content, this.toolCalls, this.done = false});
  final String? content;
  final List<ToolCallDelta>? toolCalls;
  final bool done;
}

class ToolCallDelta {
  const ToolCallDelta({this.index, this.id, this.name, this.arguments});
  final int? index;
  final String? id;
  final String? name;
  final String? arguments;
}

class ToolDefinition {
  const ToolDefinition({
    required this.name,
    required this.description,
    required this.parameters,
  });
  final String name;
  final String description;
  final Map<String, dynamic> parameters;
}

class ToolCall {
  const ToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });
  final String id;
  final String name;
  final String arguments;
}

abstract class LlmProvider {
  Future<String> generate(String prompt);
  Future<String> generateWithSystem(String system, String user);
  Future<ChatResponse> generateChat({
    required List<ChatMessageForApi> messages,
    List<ToolDefinition>? tools,
  });
  Stream<ChatStreamDelta> generateChatStream({
    required List<ChatMessageForApi> messages,
    List<ToolDefinition>? tools,
  });
  void close();
}

class LlmError implements Exception {
  LlmError(this.message);
  final String message;
  @override
  String toString() => message;
}
