import 'dart:async';
import '../../core/network/network_logger.dart';
import '../../core/utils/sentence_chunker.dart';
import '../../features/chat/data/models/chat_message.dart';
import '../../features/settings/data/models/api_keys_model.dart';
import '../../features/settings/data/models/persona_model.dart';
import '../../features/settings/data/models/voice_config_model.dart';
import '../llm/llm_service_factory.dart';
import '../voice/stt_service.dart';
import '../voice/tts_queue_manager.dart';

enum PipelineStatus { idle, listening, thinking, speaking, error }

class VoicePipelineCoordinator {
  final SttService sttService;
  final TtsQueueManager ttsQueueManager;
  final LlmServiceFactory llmFactory;
  final SentenceChunker _sentenceChunker = SentenceChunker();

  PipelineStatus _status = PipelineStatus.idle;
  StreamSubscription<String>? _llmStreamSubscription;
  Timer? _streamTimeoutTimer;

  // Broadcast stream controllers to support multiple concurrent listeners (ChatBloc, ContinuousVoiceScreen, etc.)
  final StreamController<PipelineStatus> _statusController = StreamController<PipelineStatus>.broadcast();
  final StreamController<String> _userTranscriptController = StreamController<String>.broadcast();
  final StreamController<String> _aiTokenController = StreamController<String>.broadcast();
  final StreamController<String> _aiResponseFinishedController = StreamController<String>.broadcast();
  final StreamController<String> _errorController = StreamController<String>.broadcast();

  // Streams
  Stream<PipelineStatus> get onStatusChangedStream => _statusController.stream;
  Stream<String> get onUserTranscriptUpdatedStream => _userTranscriptController.stream;
  Stream<String> get onAiTokenReceivedStream => _aiTokenController.stream;
  Stream<String> get onAiResponseFinishedStream => _aiResponseFinishedController.stream;
  Stream<String> get onErrorStream => _errorController.stream;

  // Status callbacks (legacy / direct assignment support)
  Function(PipelineStatus status)? onStatusChanged;
  Function(String text)? onUserTranscriptUpdated;
  Function(String partialAiResponse)? onAiTokenReceived;
  Function(String completeAiResponse)? onAiResponseFinished;
  Function(String error)? onError;

  PipelineStatus get status => _status;

  VoicePipelineCoordinator({
    required this.sttService,
    required this.ttsQueueManager,
    required this.llmFactory,
  }) {
    ttsQueueManager.onQueueStarted = () {
      _setStatus(PipelineStatus.speaking);
    };
    ttsQueueManager.onQueueFinished = () {
      if (_status == PipelineStatus.speaking) {
        _setStatus(PipelineStatus.idle);
      }
    };
  }

  void _setStatus(PipelineStatus newStatus) {
    _status = newStatus;
    if (!_statusController.isClosed) {
      _statusController.add(_status);
    }
    onStatusChanged?.call(_status);
  }

  void _notifyTranscript(String text) {
    if (!_userTranscriptController.isClosed) {
      _userTranscriptController.add(text);
    }
    onUserTranscriptUpdated?.call(text);
  }

  void _notifyAiToken(String text) {
    if (!_aiTokenController.isClosed) {
      _aiTokenController.add(text);
    }
    onAiTokenReceived?.call(text);
  }

  void _notifyAiFinished(String text) {
    if (!_aiResponseFinishedController.isClosed) {
      _aiResponseFinishedController.add(text);
    }
    onAiResponseFinished?.call(text);
  }

  void _notifyError(String err) {
    if (!_errorController.isClosed) {
      _errorController.add(err);
    }
    onError?.call(err);
  }

  /// Starts listening to the user's speech via the configured STT engine.
  Future<void> startListening({
    required ApiKeysModel apiKeys,
    required VoiceConfigModel voiceConfig,
  }) async {
    // If TTS is currently speaking, barge-in / interrupt it!
    await interrupt();

    _setStatus(PipelineStatus.listening);

    try {
      await sttService.startListening(
        mode: apiKeys.sttMode,
        languageCode: voiceConfig.languageCode,
        groqApiKey: apiKeys.groqKey,
        onResult: (transcript, isFinal) {
          _notifyTranscript(transcript);
        },
        onError: (err) {
          _setStatus(PipelineStatus.error);
          _notifyError(err);
        },
      );
    } catch (e) {
      _setStatus(PipelineStatus.error);
      _notifyError(e.toString());
    }
  }

  /// Stops speech listening and executes the LLM pipeline with the resulting text.
  Future<void> stopListeningAndProcess({
    required List<ChatMessage> conversationHistory,
    required ApiKeysModel apiKeys,
    required PersonaModel persona,
    required VoiceConfigModel voiceConfig,
    String? fallbackTranscript,
  }) async {
    String? recognizedText;

    try {
      recognizedText = await sttService.stopListening(
        mode: apiKeys.sttMode,
        groqApiKey: apiKeys.groqKey,
        languageCode: voiceConfig.languageCode,
      );
    } catch (e) {
      _setStatus(PipelineStatus.error);
      _notifyError(e.toString());
      return;
    }

    final query = (recognizedText ?? fallbackTranscript ?? '').trim();
    if (query.isEmpty) {
      _setStatus(PipelineStatus.idle);
      return;
    }

    _notifyTranscript(query);
    await processTextQuery(
      userQuery: query,
      conversationHistory: conversationHistory,
      apiKeys: apiKeys,
      persona: persona,
      voiceConfig: voiceConfig,
      enableVoicePlayback: true,
    );
  }

  /// Core streaming pipeline:
  /// Takes user input -> calls selected LLM provider -> chunks sentences -> feeds TTS queue immediately.
  Future<void> processTextQuery({
    required String userQuery,
    required List<ChatMessage> conversationHistory,
    required ApiKeysModel apiKeys,
    required PersonaModel persona,
    required VoiceConfigModel voiceConfig,
    bool enableVoicePlayback = true,
  }) async {
    await interrupt();

    _setStatus(PipelineStatus.thinking);
    _sentenceChunker.reset();

    final provider = llmFactory.getProvider(apiKeys.selectedProvider);
    final StringBuffer fullResponseBuffer = StringBuffer();

    // Determine the API key for selected provider
    String activeApiKey = '';
    switch (apiKeys.selectedProvider) {
      case 'groq':
        activeApiKey = apiKeys.groqKey.trim();
        break;
      case 'openrouter':
        activeApiKey = apiKeys.openRouterKey.trim();
        break;
      case 'gemini':
      default:
        activeApiKey = apiKeys.geminiKey.trim();
        break;
    }

    if (activeApiKey.isEmpty) {
      _setStatus(PipelineStatus.error);
      final providerName = apiKeys.selectedProvider.toUpperCase();
      _notifyError('$providerName API Key is missing. Please set it in Settings & Keys.');
      return;
    }

    // Build context history: clean up empty or in-flight placeholder messages
    final cleanHistory = <ChatMessage>[];
    for (final msg in conversationHistory) {
      if (msg.isStreaming || msg.content.trim().isEmpty || msg.isError) {
        continue;
      }
      cleanHistory.add(msg);
    }

    final updatedHistory = [
      ...cleanHistory,
      ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: userQuery,
        isUser: true,
        timestamp: DateTime.now(),
      ),
    ];

    try {
      final tokenStream = provider.streamChat(
        history: updatedHistory,
        systemPrompt: persona.systemPrompt,
        apiKey: activeApiKey,
        model: apiKeys.selectedModel,
        customBaseUrl: apiKeys.openRouterBaseUrl,
      );

      // Timeout watchdog: if no response from LLM within 60 seconds, abort safely
      _streamTimeoutTimer?.cancel();
      _streamTimeoutTimer = Timer(const Duration(seconds: 60), () {
        if (_status == PipelineStatus.thinking) {
          _llmStreamSubscription?.cancel();
          _setStatus(PipelineStatus.error);
          _notifyError('Yêu cầu AI đã hết thời gian chờ phản hồi (Timeout). Vui lòng thử lại.');
        }
      });

      _llmStreamSubscription = tokenStream.listen(
        (token) {
          _streamTimeoutTimer?.cancel();
          fullResponseBuffer.write(token);
          _notifyAiToken(fullResponseBuffer.toString());

          // Sentence-boundary chunking
          if (enableVoicePlayback) {
            final completedSentences = _sentenceChunker.processToken(token);
            for (final sentence in completedSentences) {
              ttsQueueManager.enqueue(sentence, voiceConfig);
            }
          }
        },
        onError: (e) {
          _streamTimeoutTimer?.cancel();
          _setStatus(PipelineStatus.error);
          final cleanErr = NetworkLogger.formatUserMessage(
            e,
            service: apiKeys.selectedProvider,
            model: apiKeys.selectedModel,
          );
          _notifyError(cleanErr);
        },
        onDone: () {
          _streamTimeoutTimer?.cancel();
          // Flush any final text remaining in the sentence chunker
          if (enableVoicePlayback) {
            final remainder = _sentenceChunker.flush();
            if (remainder != null && remainder.isNotEmpty) {
              ttsQueueManager.enqueue(remainder, voiceConfig);
            }
          }

          _notifyAiFinished(fullResponseBuffer.toString());

          if (!enableVoicePlayback || !ttsQueueManager.isSpeaking) {
            _setStatus(PipelineStatus.idle);
          }
        },
        cancelOnError: true,
      );
    } catch (e) {
      _streamTimeoutTimer?.cancel();
      _setStatus(PipelineStatus.error);
      final cleanErr = NetworkLogger.formatUserMessage(
        e,
        service: apiKeys.selectedProvider,
        model: apiKeys.selectedModel,
      );
      _notifyError(cleanErr);
    }
  }

  /// Cancels any active LLM stream and stops TTS audio playback immediately (barge-in).
  Future<void> interrupt() async {
    _streamTimeoutTimer?.cancel();
    _streamTimeoutTimer = null;
    await _llmStreamSubscription?.cancel();
    _llmStreamSubscription = null;
    _sentenceChunker.reset();
    await ttsQueueManager.stopAndClear();
    await sttService.cancel();
    if (_status != PipelineStatus.idle) {
      _setStatus(PipelineStatus.idle);
    }
  }

  void dispose() {
    interrupt();
    sttService.dispose();
    ttsQueueManager.dispose();
    _statusController.close();
    _userTranscriptController.close();
    _aiTokenController.close();
    _aiResponseFinishedController.close();
    _errorController.close();
  }
}
