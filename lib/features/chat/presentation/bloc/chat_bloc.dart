import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../services/llm/memory_extractor_service.dart';
import '../../../../services/pipeline/voice_pipeline_coordinator.dart';
import '../../../../services/storage/chat_local_storage_service.dart';
import '../../../character/data/character_library.dart';
import '../../../character/data/models/ai_character_model.dart';
import '../../../profile/data/models/user_profile_model.dart';
import '../../../settings/data/models/persona_model.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/chat_session.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final VoicePipelineCoordinator coordinator;
  final ChatLocalStorageService storageService;
  final SettingsBloc settingsBloc;
  final MemoryExtractorService _memoryExtractor;

  ChatSession? _currentSession;
  StreamSubscription<String>? _aiTokenSub;
  StreamSubscription<String>? _aiFinishSub;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<String>? _transcriptSub;
  StreamSubscription<String>? _fallbackSub;

  ChatBloc({
    required this.coordinator,
    required this.storageService,
    required this.settingsBloc,
  })  : _memoryExtractor = MemoryExtractorService(coordinator.llmFactory),
        super(const ChatState()) {
    on<LoadChatHistoryEvent>(_onLoadChatHistory);
    on<SwitchSessionEvent>(_onSwitchSession);
    on<CreateSessionWithCharacterEvent>(_onCreateSessionWithCharacter);
    on<DeleteSessionEvent>(_onDeleteSession);
    on<TogglePinSessionEvent>(_onTogglePinSession);
    on<ToggleArchiveSessionEvent>(_onToggleArchiveSession);
    on<UpdateUserProfileEvent>(_onUpdateUserProfile);
    on<AddMemoryNoteEvent>(_onAddMemoryNote);
    on<ClearMemoryNotesEvent>(_onClearMemoryNotes);
    on<SearchSessionsEvent>(_onSearchSessions);
    on<FilterSessionsEvent>(_onFilterSessions);

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
    on<NotifyFallbackEvent>((event, emit) {
      emit(state.copyWith(errorMessage: 'ℹ️ ${event.message}'));
    });

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

    _fallbackSub = coordinator.onFallbackNotificationStream.listen((msg) {
      add(NotifyFallbackEvent(msg));
    });
  }

  Future<void> _onLoadChatHistory(
    LoadChatHistoryEvent event,
    Emitter<ChatState> emit,
  ) async {
    final userProfile = storageService.loadUserProfile();
    final sessions = storageService.loadSessions();

    if (sessions.isNotEmpty) {
      _currentSession = sessions.first;
      emit(state.copyWith(
        allSessions: sessions,
        activeSession: _currentSession,
        messages: _currentSession!.messages,
        userProfile: userProfile,
      ));
    } else {
      // Seed first session with primary companion character
      final defaultChar = CharacterLibrary.getFeaturedCharacters().first;
      _initNewSessionWithCharacter(defaultChar);
      final initialSessions = [_currentSession!];
      await storageService.saveSession(_currentSession!);

      emit(state.copyWith(
        allSessions: initialSessions,
        activeSession: _currentSession,
        messages: _currentSession!.messages,
        userProfile: userProfile,
      ));
    }
  }

  void _initNewSessionWithCharacter(AICharacterModel character) {
    _currentSession = ChatSession(
      id: const Uuid().v4(),
      title: 'Trò chuyện với ${character.name}',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      characterId: character.id,
      characterName: character.name,
      characterAvatar: character.avatar,
      systemPrompt: character.systemPrompt,
      voiceId: character.voiceId,
      messages: [
        ChatMessage(
          id: const Uuid().v4(),
          content: character.sampleGreeting,
          isUser: false,
          timestamp: DateTime.now(),
          personaName: character.name,
        )
      ],
    );
  }

  Future<void> _onSwitchSession(
    SwitchSessionEvent event,
    Emitter<ChatState> emit,
  ) async {
    await coordinator.interrupt();
    final sessions = storageService.loadSessions();
    final target = sessions.firstWhere(
      (s) => s.id == event.sessionId,
      orElse: () => _currentSession ?? sessions.first,
    );

    _currentSession = target;
    emit(state.copyWith(
      activeSession: _currentSession,
      messages: _currentSession!.messages,
      isStreaming: false,
      isListeningStt: false,
      isSpeakingTts: false,
      errorMessage: null,
    ));
  }

  Future<void> _onCreateSessionWithCharacter(
    CreateSessionWithCharacterEvent event,
    Emitter<ChatState> emit,
  ) async {
    await coordinator.interrupt();
    _initNewSessionWithCharacter(event.character);
    await storageService.saveSession(_currentSession!);

    final sessions = storageService.loadSessions();
    emit(state.copyWith(
      allSessions: sessions,
      activeSession: _currentSession,
      messages: _currentSession!.messages,
      isStreaming: false,
      isListeningStt: false,
      isSpeakingTts: false,
      errorMessage: null,
    ));
  }

  Future<void> _onDeleteSession(
    DeleteSessionEvent event,
    Emitter<ChatState> emit,
  ) async {
    await storageService.deleteSession(event.sessionId);
    final sessions = storageService.loadSessions();

    if (_currentSession?.id == event.sessionId) {
      if (sessions.isNotEmpty) {
        _currentSession = sessions.first;
      } else {
        final defaultChar = CharacterLibrary.getFeaturedCharacters().first;
        _initNewSessionWithCharacter(defaultChar);
        await storageService.saveSession(_currentSession!);
      }
    }

    final updatedSessions = storageService.loadSessions();
    emit(state.copyWith(
      allSessions: updatedSessions,
      activeSession: _currentSession,
      messages: _currentSession?.messages ?? const [],
    ));
  }

  Future<void> _onTogglePinSession(
    TogglePinSessionEvent event,
    Emitter<ChatState> emit,
  ) async {
    await storageService.togglePinSession(event.sessionId);
    final sessions = storageService.loadSessions();
    if (_currentSession?.id == event.sessionId) {
      _currentSession = sessions.firstWhere((s) => s.id == event.sessionId);
    }
    emit(state.copyWith(
      allSessions: sessions,
      activeSession: _currentSession,
    ));
  }

  Future<void> _onToggleArchiveSession(
    ToggleArchiveSessionEvent event,
    Emitter<ChatState> emit,
  ) async {
    await storageService.toggleArchiveSession(event.sessionId);
    final sessions = storageService.loadSessions();
    if (_currentSession?.id == event.sessionId) {
      _currentSession = sessions.firstWhere((s) => s.id == event.sessionId);
    }
    emit(state.copyWith(
      allSessions: sessions,
      activeSession: _currentSession,
    ));
  }

  Future<void> _onUpdateUserProfile(
    UpdateUserProfileEvent event,
    Emitter<ChatState> emit,
  ) async {
    await storageService.saveUserProfile(event.profile);
    emit(state.copyWith(userProfile: event.profile));
  }

  Future<void> _onAddMemoryNote(
    AddMemoryNoteEvent event,
    Emitter<ChatState> emit,
  ) async {
    if (_currentSession == null || event.note.trim().isEmpty) return;

    final updatedNotes = List<String>.from(_currentSession!.memoryNotes)..add(event.note.trim());
    _currentSession = _currentSession!.copyWith(
      memoryNotes: updatedNotes,
      updatedAt: DateTime.now(),
    );
    await storageService.saveSession(_currentSession!);

    final sessions = storageService.loadSessions();
    emit(state.copyWith(
      allSessions: sessions,
      activeSession: _currentSession,
    ));
  }

  Future<void> _onClearMemoryNotes(
    ClearMemoryNotesEvent event,
    Emitter<ChatState> emit,
  ) async {
    if (_currentSession == null) return;

    _currentSession = _currentSession!.copyWith(
      memoryNotes: const [],
      updatedAt: DateTime.now(),
    );
    await storageService.saveSession(_currentSession!);

    final sessions = storageService.loadSessions();
    emit(state.copyWith(
      allSessions: sessions,
      activeSession: _currentSession,
    ));
  }

  void _onSearchSessions(
    SearchSessionsEvent event,
    Emitter<ChatState> emit,
  ) {
    emit(state.copyWith(searchQuery: event.query));
  }

  void _onFilterSessions(
    FilterSessionsEvent event,
    Emitter<ChatState> emit,
  ) {
    emit(state.copyWith(sessionFilter: event.filter));
  }

  /// Builds the effective dynamic persona for this active conversation session,
  /// integrating character personality + user age-group/style + session memories.
  PersonaModel _buildSessionPersona() {
    final active = _currentSession;
    final fallback = settingsBloc.state.activePersona;

    final charName = active?.characterName ?? fallback.name;
    final charAvatar = active?.characterAvatar ?? fallback.avatarEmoji;
    final charPrompt = (active?.systemPrompt != null && active!.systemPrompt!.isNotEmpty)
        ? active.systemPrompt!
        : fallback.systemPrompt;

    final profileAddon = state.userProfile.buildSystemPromptAddon();
    final memoryAddon = (active != null && active.memoryNotes.isNotEmpty)
        ? '\n[Ký ức & ghi nhớ riêng cho cuộc trò chuyện này]:\n- ${active.memoryNotes.join('\n- ')}'
        : '';

    return PersonaModel(
      id: active?.characterId ?? fallback.id,
      name: charName,
      description: 'Nhân cách AI chuyên biệt',
      avatarEmoji: charAvatar,
      systemPrompt: '$charPrompt$profileAddon$memoryAddon',
      defaultPitch: fallback.defaultPitch,
      defaultRate: fallback.defaultRate,
      languageCode: fallback.languageCode,
      isBuiltIn: false,
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

    final sessionPersona = _buildSessionPersona();

    final aiPlaceholder = ChatMessage(
      id: const Uuid().v4(),
      content: '',
      isUser: false,
      timestamp: DateTime.now(),
      isStreaming: true,
      personaName: sessionPersona.name,
    );

    final updated = [...historySnapshot, userMsg, aiPlaceholder];
    emit(state.copyWith(
      messages: updated,
      isStreaming: true,
      errorMessage: null,
    ));

    final settings = settingsBloc.state;
    // Bind character voice if specified
    var effectiveVoiceConfig = settings.voiceConfig;
    if (_currentSession?.voiceId != null && _currentSession!.voiceId!.isNotEmpty) {
      effectiveVoiceConfig = effectiveVoiceConfig.copyWith(
        selectedVoiceId: _currentSession!.voiceId,
      );
    }

    try {
      await coordinator.processTextQuery(
        userQuery: text,
        conversationHistory: historySnapshot,
        apiKeys: settings.apiKeys,
        persona: sessionPersona,
        voiceConfig: effectiveVoiceConfig,
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

    // Auto-Memory Extraction (TASK 3): Trigger background extraction every 6 messages
    if (updatedList.length >= 4 && updatedList.length % 6 == 0) {
      _triggerBackgroundMemoryExtraction(updatedList);
    }
  }

  void _triggerBackgroundMemoryExtraction(List<ChatMessage> messages) {
    if (_currentSession == null) return;
    final sessionId = _currentSession!.id;
    final recent = messages.length > 6 ? messages.sublist(messages.length - 6) : messages;
    final existing = List<String>.from(_currentSession!.memoryNotes);
    final apiKeys = settingsBloc.state.apiKeys;

    _memoryExtractor.extractNewMemories(
      recentMessages: recent,
      existingNotes: existing,
      apiKeys: apiKeys,
    ).then((newNotes) async {
      if (newNotes.isNotEmpty && _currentSession?.id == sessionId) {
        final combined = [..._currentSession!.memoryNotes, ...newNotes];
        _currentSession = _currentSession!.copyWith(
          memoryNotes: combined,
          updatedAt: DateTime.now(),
        );
        await storageService.saveSession(_currentSession!);
        final all = storageService.loadSessions();
        add(SearchSessionsEvent(state.searchQuery));
      }
    });
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

    var voiceConfig = settingsBloc.state.voiceConfig;
    if (_currentSession?.voiceId != null && _currentSession!.voiceId!.isNotEmpty) {
      voiceConfig = voiceConfig.copyWith(selectedVoiceId: _currentSession!.voiceId);
    }

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
    final sessionPersona = _buildSessionPersona();
    var voiceConfig = settings.voiceConfig;
    if (_currentSession?.voiceId != null && _currentSession!.voiceId!.isNotEmpty) {
      voiceConfig = voiceConfig.copyWith(selectedVoiceId: _currentSession!.voiceId);
    }

    try {
      await coordinator.stopListeningAndProcess(
        conversationHistory: state.messages,
        apiKeys: settings.apiKeys,
        persona: sessionPersona,
        voiceConfig: voiceConfig,
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
    if (_currentSession != null) {
      _currentSession = _currentSession!.copyWith(
        messages: const [],
        updatedAt: DateTime.now(),
      );
      await storageService.saveSession(_currentSession!);
      final all = storageService.loadSessions();
      emit(state.copyWith(messages: const [], allSessions: all, activeSession: _currentSession));
    } else {
      emit(state.copyWith(messages: const []));
    }
  }

  void _onSetAutoScrollLockEvent(
    SetAutoScrollLockEvent event,
    Emitter<ChatState> emit,
  ) {
    emit(state.copyWith(isAutoScrollLocked: event.isLocked));
  }

  Future<void> _saveCurrentMessages(List<ChatMessage> messages) async {
    if (_currentSession == null) {
      final defaultChar = CharacterLibrary.getFeaturedCharacters().first;
      _initNewSessionWithCharacter(defaultChar);
    }

    // Auto update title if still default and we have user questions
    var title = _currentSession!.title;
    if ((title.startsWith('Trò chuyện với') || title == 'New Conversation') && messages.length >= 2) {
      final firstUser = messages.firstWhere((m) => m.isUser, orElse: () => messages.first);
      if (firstUser.isUser && firstUser.content.isNotEmpty) {
        title = firstUser.content.length > 32
            ? '${firstUser.content.substring(0, 32)}...'
            : firstUser.content;
      }
    }

    _currentSession = _currentSession!.copyWith(
      title: title,
      messages: messages,
      updatedAt: DateTime.now(),
    );

    await storageService.saveSession(_currentSession!);
    final all = storageService.loadSessions();
    emit(state.copyWith(allSessions: all, activeSession: _currentSession));
  }

  @override
  Future<void> close() {
    _aiTokenSub?.cancel();
    _aiFinishSub?.cancel();
    _errorSub?.cancel();
    _transcriptSub?.cancel();
    _fallbackSub?.cancel();
    coordinator.dispose();
    return super.close();
  }
}
