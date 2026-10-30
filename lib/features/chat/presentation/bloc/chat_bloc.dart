import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../services/pipeline/voice_pipeline_coordinator.dart';
import '../../../../services/storage/chat_local_storage_service.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/chat_session.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final VoicePipelineCoordinator coordinator;
  final ChatLocalStorageService storageService;
  final SettingsBloc settingsBloc;

  ChatSession? _currentSession;
  StreamSubscription<String>? _aiTokenSub;
  StreamSubscription<String>? _aiFinishSub;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<String>? _transcriptSub;

  ChatBloc({
    required this.coordinator,
    required this.storageService,
    required this.settingsBloc,
  }) : super(const ChatState()) {
    on<LoadChatHistoryEvent>(_onLoadChatHistory);
    on<SendTextMessageEvent>(_onSendTextMessage);
    on<ReceiveAiStreamTokenEvent>(_onReceiveAiStreamToken);
    on<FinishAiStreamEvent>(_onFinishAiStream);
    on<FailAiStreamEvent>(_onFailAiStream);
    on<SpeakMessageTtsEvent>(_onSpeakMessageTts);
    on<StopTtsPlaybackEvent>(_onStopTtsPlayback);
    on<StartTapToSpeakEvent>(_onStartTapToSpeak);
    on<StopTapToSpeakEvent>(_onStopTapToSpeak);
    on<UpdateSttTranscriptPreviewEvent>(_onUpdateSttTranscriptPreview);
    on<ClearChatEvent>(_onClearChat);
    on<SetAutoScrollLockEvent>(_onSetAutoScrollLockEvent);

    _bindCoordinatorSubscriptions();
  }

  void _bindCoordinatorSubscriptions() {
    _aiTokenSub = coordinator.onAiTokenReceivedStream.listen((accumulated) {
      add(ReceiveAiStreamTokenEvent(accumulated));
    });

    _aiFinishSub = coordinator.onAiResponseFinishedStream.listen((finalText) {
      add(FinishAiStreamEvent(finalText));
    });

    _errorSub = coordinator.onErrorStream.listen((err) {
      add(FailAiStreamEvent(err));
    });

    _transcriptSub = coordinator.onUserTranscriptUpdatedStream.listen((transcript) {
      add(UpdateSttTranscriptPreviewEvent(transcript));
    });
  }

  Future<void> _onLoadChatHistory(
    LoadChatHistoryEvent event,
    Emitter<ChatState> emit,
  ) async {
    final sessions = storageService.loadSessions();
    if (sessions.isNotEmpty) {
      _currentSession = sessions.first;
      emit(state.copyWith(messages: _currentSession!.messages));
    } else {
      _initNewSession();
      emit(state.copyWith(messages: []));
    }
  }

  void _initNewSession() {
    _currentSession = ChatSession(
      id: const Uuid().v4(),
      title: 'New Conversation',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      messages: const [],
    );
  }

  Future<void> _onSendTextMessage(
    SendTextMessageEvent event,
    Emitter<ChatState> emit,
  ) async {
    final text = event.text.trim();
    if (text.isEmpty || state.isStreaming) return;

    // Snapshot existing messages BEFORE adding user query & placeholder
    final historySnapshot = List<ChatMessage>.from(state.messages);

    final userMsg = ChatMessage(
      id: const Uuid().v4(),
      content: text,
      isUser: true,
      timestamp: DateTime.now(),
    );

    final aiPlaceholder = ChatMessage(
      id: const Uuid().v4(),
      content: '',
      isUser: false,
      timestamp: DateTime.now(),
      isStreaming: true,
      personaName: settingsBloc.state.activePersona.name,
    );

    final updated = [...historySnapshot, userMsg, aiPlaceholder];
    emit(state.copyWith(
      messages: updated,
      isStreaming: true,
      errorMessage: null,
    ));

    final settings = settingsBloc.state;
    try {
      await coordinator.processTextQuery(
        userQuery: text,
        conversationHistory: historySnapshot,
        apiKeys: settings.apiKeys,
        persona: settings.activePersona,
        voiceConfig: settings.voiceConfig,
        enableVoicePlayback: event.enableVoicePlayback,
      );
    } catch (e) {
      add(FailAiStreamEvent(e.toString()));
    }
  }

  void _onReceiveAiStreamToken(
    ReceiveAiStreamTokenEvent event,
    Emitter<ChatState> emit,
  ) {
    if (state.messages.isEmpty) return;

    final last = state.messages.last;
    if (!last.isUser && last.isStreaming) {
      final updatedList = List<ChatMessage>.from(state.messages);
      updatedList[updatedList.length - 1] = last.copyWith(
        content: event.fullAccumulatedText,
      );
      emit(state.copyWith(messages: updatedList));
    }
  }

  Future<void> _onFinishAiStream(
    FinishAiStreamEvent event,
    Emitter<ChatState> emit,
  ) async {
    if (state.messages.isEmpty) {
      emit(state.copyWith(isStreaming: false));
      return;
    }

    final last = state.messages.last;
    final updatedList = List<ChatMessage>.from(state.messages);

    if (!last.isUser && last.isStreaming) {
      final text = event.fullText.trim();
      updatedList[updatedList.length - 1] = last.copyWith(
        content: text.isEmpty ? '(Không nhận được phản hồi từ AI)' : text,
        isStreaming: false,
      );
    }

    emit(state.copyWith(
      messages: updatedList,
      isStreaming: false,
    ));

    await _saveCurrentMessages(updatedList);
  }

  void _onFailAiStream(
    FailAiStreamEvent event,
    Emitter<ChatState> emit,
  ) {
    if (state.messages.isEmpty) {
      emit(state.copyWith(isStreaming: false, errorMessage: event.errorMessage));
      return;
    }

    final last = state.messages.last;
    final updatedList = List<ChatMessage>.from(state.messages);

    if (!last.isUser && last.isStreaming) {
      updatedList[updatedList.length - 1] = last.copyWith(
        content: '⚠️ ${event.errorMessage}',
        isStreaming: false,
        isError: true,
      );
    }

    emit(state.copyWith(
      messages: updatedList,
      isStreaming: false,
      errorMessage: event.errorMessage,
    ));
  }

  Future<void> _onSpeakMessageTts(
    SpeakMessageTtsEvent event,
    Emitter<ChatState> emit,
  ) async {
    emit(state.copyWith(
      isSpeakingTts: true,
      activeSpeakingMessageId: event.messageId,
    ));

    final voiceConfig = settingsBloc.state.voiceConfig;
    await coordinator.ttsQueueManager.stopAndClear();
    coordinator.ttsQueueManager.enqueue(event.text, voiceConfig);

    coordinator.ttsQueueManager.onQueueFinished = () {
      add(StopTtsPlaybackEvent());
    };
  }

  Future<void> _onStopTtsPlayback(
    StopTtsPlaybackEvent event,
    Emitter<ChatState> emit,
  ) async {
    await coordinator.ttsQueueManager.stopAndClear();
    emit(state.copyWith(
      isSpeakingTts: false,
      activeSpeakingMessageId: null,
    ));
  }

  Future<void> _onStartTapToSpeak(
    StartTapToSpeakEvent event,
    Emitter<ChatState> emit,
  ) async {
    emit(state.copyWith(isListeningStt: true, sttTranscriptPreview: ''));
    final settings = settingsBloc.state;
    await coordinator.startListening(
      apiKeys: settings.apiKeys,
      voiceConfig: settings.voiceConfig,
    );
  }

  Future<void> _onStopTapToSpeak(
    StopTapToSpeakEvent event,
    Emitter<ChatState> emit,
  ) async {
    final preview = state.sttTranscriptPreview;
    emit(state.copyWith(isListeningStt: false));

    final settings = settingsBloc.state;
    try {
      await coordinator.stopListeningAndProcess(
        conversationHistory: state.messages,
        apiKeys: settings.apiKeys,
        persona: settings.activePersona,
        voiceConfig: settings.voiceConfig,
        fallbackTranscript: preview,
      );
    } catch (e) {
      add(FailAiStreamEvent(e.toString()));
    }
  }

  void _onUpdateSttTranscriptPreview(
    UpdateSttTranscriptPreviewEvent event,
    Emitter<ChatState> emit,
  ) {
    emit(state.copyWith(sttTranscriptPreview: event.transcript));
  }

  Future<void> _onClearChat(
    ClearChatEvent event,
    Emitter<ChatState> emit,
  ) async {
    await coordinator.interrupt();
    _initNewSession();
    await storageService.clearAll();
    emit(const ChatState());
  }

  void _onSetAutoScrollLockEvent(
    SetAutoScrollLockEvent event,
    Emitter<ChatState> emit,
  ) {
    emit(state.copyWith(isAutoScrollLocked: event.isLocked));
  }

  Future<void> _saveCurrentMessages(List<ChatMessage> messages) async {
    if (_currentSession == null) {
      _initNewSession();
    }
    _currentSession = _currentSession!.copyWith(
      messages: messages,
      updatedAt: DateTime.now(),
    );
    await storageService.saveSession(_currentSession!);
  }

  @override
  Future<void> close() {
    _aiTokenSub?.cancel();
    _aiFinishSub?.cancel();
    _errorSub?.cancel();
    _transcriptSub?.cancel();
    coordinator.dispose();
    return super.close();
  }
}
