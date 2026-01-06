class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final ChatMessageType messageType;
  final Map<String, dynamic>? actionData;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.messageType = ChatMessageType.text,
    this.actionData,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'messageType': messageType.toString(),
      'actionData': actionData,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      text: json['text'],
      isUser: json['isUser'],
      timestamp: DateTime.parse(json['timestamp']),
      messageType: ChatMessageType.values.firstWhere(
        (e) => e.toString() == json['messageType'],
        orElse: () => ChatMessageType.text,
      ),
      actionData: json['actionData'],
    );
  }
}

enum ChatMessageType {
  text,
  welcome,
  movieInfo,
  bookingConfirmation,
  error,
  quickReply,
  actionRequired,
}

class ChatResponse {
  final String text;
  final ChatMessageType messageType;
  final Map<String, dynamic>? actionData;

  ChatResponse({
    required this.text,
    this.messageType = ChatMessageType.text,
    this.actionData,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      text: json['text'] ?? '',
      messageType: ChatMessageType.values.firstWhere(
        (e) => e.toString() == json['messageType'],
        orElse: () => ChatMessageType.text,
      ),
      actionData: json['actionData'],
    );
  }
}
