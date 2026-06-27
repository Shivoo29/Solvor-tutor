import '../../../core/mascot/mascot_painter.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isStreaming;

  const ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isStreaming = false,
  });

  ChatMessage copyWith({String? text, bool? isStreaming}) => ChatMessage(
        text: text ?? this.text,
        isUser: isUser,
        timestamp: timestamp,
        isStreaming: isStreaming ?? this.isStreaming,
      );
}

class ChatState {
  final List<ChatMessage> messages;
  final bool isTyping;
  final MascotEmotion mascotEmotion;
  final bool gemmaReady;

  const ChatState({
    this.messages = const [],
    this.isTyping = false,
    this.mascotEmotion = MascotEmotion.greeting,
    this.gemmaReady = false,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isTyping,
    MascotEmotion? mascotEmotion,
    bool? gemmaReady,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        isTyping: isTyping ?? this.isTyping,
        mascotEmotion: mascotEmotion ?? this.mascotEmotion,
        gemmaReady: gemmaReady ?? this.gemmaReady,
      );
}
