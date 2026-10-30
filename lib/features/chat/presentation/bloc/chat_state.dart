import 'package:equatable/equatable.dart';
import '../../data/models/chat_message.dart';

class ChatState extends Equatable {
  final List<ChatMessage> messages;
  final bool isStreaming;
  final bool isListeningStt;
  final String sttTranscriptPreview;
  final bool isSpeakingTts;
  final String? activeSpeakingMessageId;
  final bool isAutoScrollLocked;
  final String? errorMessage;

  const ChatState({
    this.messages = const [],
    this.isStreaming = false,
    this.isListeningStt = false,
    this.sttTranscriptPreview = '',
    this.isSpeakingTts = false,
    this.activeSpeakingMessageId,
    this.isAutoScrollLocked = false,
    this.errorMessage,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isStreaming,
    bool? isListeningStt,
    String? sttTranscriptPreview,
    bool? isSpeakingTts,
    String? activeSpeakingMessageId,
    bool? isAutoScrollLocked,
    String? errorMessage,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isStreaming: isStreaming ?? this.isStreaming,
      isListeningStt: isListeningStt ?? this.isListeningStt,
      sttTranscriptPreview: sttTranscriptPreview ?? this.sttTranscriptPreview,
      isSpeakingTts: isSpeakingTts ?? this.isSpeakingTts,
      activeSpeakingMessageId: activeSpeakingMessageId ?? this.activeSpeakingMessageId,
      isAutoScrollLocked: isAutoScrollLocked ?? this.isAutoScrollLocked,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        messages,
        isStreaming,
        isListeningStt,
        sttTranscriptPreview,
        isSpeakingTts,
        activeSpeakingMessageId,
        isAutoScrollLocked,
        errorMessage,
      ];
}
