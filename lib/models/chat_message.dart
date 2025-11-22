enum MessageType { system, user, assistant }

class ChatMessage {
  final String content;
  final MessageType type;
  final DateTime timestamp;

  ChatMessage({
    required this.content,
    required this.type,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  static ChatMessage system(String content) => ChatMessage(
        content: content,
        type: MessageType.system,
      );

  static ChatMessage user(String content) => ChatMessage(
        content: content,
        type: MessageType.user,
      );

  static ChatMessage assistant(String content) => ChatMessage(
        content: content,
        type: MessageType.assistant,
      );
}

class Message {
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final String? additionalData; // For JSON response or other metadata

  Message({
    required this.content,
    required this.isUser,
    DateTime? timestamp,
    this.additionalData,
  }) : timestamp = timestamp ?? DateTime.now();
}
