import 'package:equatable/equatable.dart';
import '../../../character/data/models/ai_character_model.dart';
import '../../../profile/data/models/user_profile_model.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

class LoadChatHistoryEvent extends ChatEvent {}

class SwitchSessionEvent extends ChatEvent {
  final String sessionId;
  const SwitchSessionEvent(this.sessionId);

  @override
  List<Object?> get props => [sessionId];
}

class CreateSessionWithCharacterEvent extends ChatEvent {
  final AICharacterModel character;
  const CreateSessionWithCharacterEvent(this.character);

  @override
  List<Object?> get props => [character];
}

class DeleteSessionEvent extends ChatEvent {
  final String sessionId;
  const DeleteSessionEvent(this.sessionId);

  @override
  List<Object?> get props => [sessionId];
}

class TogglePinSessionEvent extends ChatEvent {
  final String sessionId;
  const TogglePinSessionEvent(this.sessionId);

  @override
  List<Object?> get props => [sessionId];
}

class ToggleArchiveSessionEvent extends ChatEvent {
  final String sessionId;
  const ToggleArchiveSessionEvent(this.sessionId);

  @override
  List<Object?> get props => [sessionId];
}

class UpdateUserProfileEvent extends ChatEvent {
  final UserProfileModel profile;
  const UpdateUserProfileEvent(this.profile);

  @override
  List<Object?> get props => [profile];
}

class AddMemoryNoteEvent extends ChatEvent {
  final String note;
  const AddMemoryNoteEvent(this.note);

  @override
  List<Object?> get props => [note];
}

class ClearMemoryNotesEvent extends ChatEvent {}

class SearchSessionsEvent extends ChatEvent {
  final String query;
  const SearchSessionsEvent(this.query);

  @override
  List<Object?> get props => [query];
}

class FilterSessionsEvent extends ChatEvent {
  final String filter; // 'all' | 'pinned' | 'archived'
  const FilterSessionsEvent(this.filter);

  @override
  List<Object?> get props => [filter];
}

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

class NotifyFallbackEvent extends ChatEvent {
  final String message;
  const NotifyFallbackEvent(this.message);

  @override
  List<Object?> get props => [message];
}
