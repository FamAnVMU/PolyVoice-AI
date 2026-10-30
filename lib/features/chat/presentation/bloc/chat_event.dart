import 'package:equatable/equatable.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

class LoadChatHistoryEvent extends ChatEvent {}

class SendTextMessageEvent extends ChatEvent {
  final String text;
  final bool enableVoicePlayback;

  const SendTextMessageEvent(this.text, {this.enableVoicePlayback = false});

  @override
  List<Object?> get props => [text, enableVoicePlayback];
}

class ReceiveAiStreamTokenEvent extends ChatEvent {
  final String fullAccumulatedText;
  const ReceiveAiStreamTokenEvent(this.fullAccumulatedText);

  @override
  List<Object?> get props => [fullAccumulatedText];
}

class FinishAiStreamEvent extends ChatEvent {
  final String fullText;
  const FinishAiStreamEvent(this.fullText);

  @override
  List<Object?> get props => [fullText];
}

class FailAiStreamEvent extends ChatEvent {
  final String errorMessage;
  const FailAiStreamEvent(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}

class SpeakMessageTtsEvent extends ChatEvent {
  final String messageId;
  final String text;
  const SpeakMessageTtsEvent({required this.messageId, required this.text});

  @override
  List<Object?> get props => [messageId, text];
}

class StopTtsPlaybackEvent extends ChatEvent {}

class StartTapToSpeakEvent extends ChatEvent {}

class StopTapToSpeakEvent extends ChatEvent {}

class UpdateSttTranscriptPreviewEvent extends ChatEvent {
  final String transcript;
  const UpdateSttTranscriptPreviewEvent(this.transcript);

  @override
  List<Object?> get props => [transcript];
}

class ClearChatEvent extends ChatEvent {}

class SetAutoScrollLockEvent extends ChatEvent {
  final bool isLocked;
  const SetAutoScrollLockEvent(this.isLocked);

  @override
  List<Object?> get props => [isLocked];
}
