import 'dart:async';
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

  // Status callbacks
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
    onStatusChanged?.call(_status);
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
          onUserTranscriptUpdated?.call(transcript);
        },
      );
    } catch (e) {
      _setStatus(PipelineStatus.error);
      onError?.call(e.toString());
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
      onError?.call(e.toString());
      return;
    }

    final query = (recognizedText ?? fallbackTranscript ?? '').trim();
    if (query.isEmpty) {
      _setStatus(PipelineStatus.idle);
      return;
    }

    onUserTranscriptUpdated?.call(query);
    await processTextQuery(
      userQuery: query,
      conversationHistory: conversationHistory,
      apiKeys: apiKeys,
      persona: persona,
      voiceConfig: voiceConfig,
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
        activeApiKey = apiKeys.groqKey;
        break;
      case 'openrouter':
        activeApiKey = apiKeys.openRouterKey;
        break;
      case 'gemini':
      default:
        activeApiKey = apiKeys.geminiKey;
        break;
    }

    // Build context history
    final updatedHistory = [
      ...conversationHistory,
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

      _llmStreamSubscription = tokenStream.listen(
        (token) {
          fullResponseBuffer.write(token);
          onAiTokenReceived?.call(fullResponseBuffer.toString());

          // Sentence-boundary chunking
          if (enableVoicePlayback) {
            final completedSentences = _sentenceChunker.processToken(token);
            for (final sentence in completedSentences) {
              ttsQueueManager.enqueue(sentence, voiceConfig);
            }
          }
        },
        onError: (e) {
          _setStatus(PipelineStatus.error);
          onError?.call(e.toString());
        },
        onDone: () {
          // Flush any final text remaining in the sentence chunker
          if (enableVoicePlayback) {
            final remainder = _sentenceChunker.flush();
            if (remainder != null && remainder.isNotEmpty) {
              ttsQueueManager.enqueue(remainder, voiceConfig);
            }
          }

          onAiResponseFinished?.call(fullResponseBuffer.toString());

          if (!enableVoicePlayback || !ttsQueueManager.isSpeaking) {
            _setStatus(PipelineStatus.idle);
          }
        },
        cancelOnError: true,
      );
    } catch (e) {
      _setStatus(PipelineStatus.error);
      onError?.call(e.toString());
    }
  }

  /// Cancels any active LLM stream and stops TTS audio playback immediately (barge-in).
  Future<void> interrupt() async {
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
  }
}
