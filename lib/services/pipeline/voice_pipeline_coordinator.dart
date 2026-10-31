import 'dart:async';
import 'package:dio/dio.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/network_logger.dart';
import '../../core/utils/sentence_chunker.dart';
import '../../core/utils/stream_response_sanitizer.dart';
import '../../features/chat/data/models/chat_message.dart';
import '../../features/settings/data/models/api_keys_model.dart';
import '../../features/settings/data/models/persona_model.dart';
import '../../features/settings/data/models/voice_config_model.dart';
import '../../features/voice/data/models/voice_configuration.dart';
import '../llm/llm_service_factory.dart';
import '../voice/stt_service.dart';
import '../voice/tts_queue_manager.dart';

enum PipelineStatus { idle, listening, thinking, speaking, error }

/// Orchestrates real-time multimodal voice/chat loops:
/// STT -> VAD Barge-in -> Context Windowing -> Multi-LLM with Auto-Fallback ->
/// Sanitizer -> Sentence Chunker -> Low-Latency TTS Queue.
/// Author: FamAn
class VoicePipelineCoordinator {
  final SttService sttService;
  final TtsQueueManager ttsQueueManager;
  final LlmServiceFactory llmFactory;
  final SentenceChunker _sentenceChunker = SentenceChunker();

  PipelineStatus _status = PipelineStatus.idle;
  StreamSubscription<String>? _llmStreamSubscription;
  Timer? _streamTimeoutTimer;
  CancelToken? _activeLlmCancelToken;

  // Broadcast stream controllers
  final StreamController<PipelineStatus> _statusController = StreamController<PipelineStatus>.broadcast();
  final StreamController<String> _userTranscriptController = StreamController<String>.broadcast();
  final StreamController<String> _aiTokenController = StreamController<String>.broadcast();
  final StreamController<String> _aiResponseFinishedController = StreamController<String>.broadcast();
  final StreamController<String> _errorController = StreamController<String>.broadcast();
  final StreamController<String> _fallbackNotificationController = StreamController<String>.broadcast();

  // Streams
  Stream<PipelineStatus> get onStatusChangedStream => _statusController.stream;
  Stream<String> get onUserTranscriptUpdatedStream => _userTranscriptController.stream;
  Stream<String> get onAiTokenReceivedStream => _aiTokenController.stream;
  Stream<String> get onAiResponseFinishedStream => _aiResponseFinishedController.stream;
  Stream<String> get onErrorStream => _errorController.stream;
  Stream<String> get onFallbackNotificationStream => _fallbackNotificationController.stream;

  // Callbacks
  Function(PipelineStatus status)? onStatusChanged;
  Function(String text)? onUserTranscriptUpdated;
  Function(String partialAiResponse)? onAiTokenReceived;
  Function(String completeAiResponse)? onAiResponseFinished;
  Function(String error)? onError;
  Function(String message)? onFallbackNotification;

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

  void _notifyFallback(String msg) {
    if (!_fallbackNotificationController.isClosed) {
      _fallbackNotificationController.add(msg);
    }
    onFallbackNotification?.call(msg);
  }

  /// Starts listening via STT. Implements Hardware AEC and Barge-in trigger.
  Future<void> startListening({
    required ApiKeysModel apiKeys,
    required VoiceConfigModel voiceConfig,
  }) async {
    // If TTS is currently speaking, barge-in / interrupt it immediately
    await interrupt();

    _setStatus(PipelineStatus.listening);

    try {
      await sttService.startListening(
        mode: apiKeys.sttMode,
        languageCode: voiceConfig.languageCode,
        groqApiKey: apiKeys.groqKey,
        onResult: (transcript, isFinal) {
          // Barge-in: If user speaks during AI speaking/thinking, abort immediately (< 50ms)
          if (_status == PipelineStatus.speaking || _status == PipelineStatus.thinking) {
            interrupt();
          }
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
    VoiceConfiguration? characterVoiceConfig,
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
      characterVoiceConfig: characterVoiceConfig,
      enableVoicePlayback: true,
    );
  }

  /// Builds a reinforced system prompt ensuring strict language consistency and in-depth responses.
  static String buildEffectiveSystemPrompt(String personaPrompt) {
    return '''$personaPrompt

QUY TẮC PHẢN HỒI VÀ NGÔN NGỮ (BẮT BUỘC TUÂN THỦ CHẶT CHẼ):
1. ĐỒNG NHẤT NGÔN NGỮ (LANGUAGE CONSISTENCY):
   - Luôn trả lời đúng ngôn ngữ mà người dùng sử dụng. Nếu người dùng hỏi bằng tiếng Việt, bạn phải trả lời 100% bằng tiếng Việt chuẩn mực, tự nhiên. Tuyệt đối KHÔNG tự ý chuyển sang tiếng Anh.
2. ĐỘ SÂU VÀ CHẤT LƯỢNG NỘI DUNG (DEPTH & COMPLETENESS):
   - Với câu hỏi phân tích, học tập, kỹ thuật: Trả lời đầy đủ, chi tiết, có chiều sâu, trình bày khoa học với Markdown.
3. CHỈ TRẢ VỀ CÂU TRẢ LỜI HOÀN CHỈNH (NO DRAFT / NO INTERNAL THOUGHTS):
   - Tuyệt đối không xuất ra bản nháp hoặc nhãn "Draft response:", "Draft:", "<think>". Chỉ cung cấp trực tiếp câu trả lời cuối cùng.
''';
  }

  /// Resolves the API key corresponding to a given provider name.
  String _getApiKeyForProvider(String providerName, ApiKeysModel apiKeys) {
    switch (providerName) {
      case AppConstants.providerGroq:
        return apiKeys.groqKey.trim();
      case AppConstants.providerOpenRouter:
        return apiKeys.openRouterKey.trim();
      case AppConstants.providerOpenAi:
        return apiKeys.openAiKey.trim();
      case AppConstants.providerAnthropic:
        return apiKeys.anthropicKey.trim();
      case AppConstants.providerLocal:
        return apiKeys.localAiBaseUrl.trim().isNotEmpty
            ? apiKeys.localAiBaseUrl.trim()
            : AppConstants.defaultLocalAiBaseUrl;
      case AppConstants.providerGemini:
      default:
        return apiKeys.geminiKey.trim();
    }
  }

  /// Builds an ordered list of fallback providers based on available keys.
  List<String> _buildFallbackCandidates(String primaryProvider, ApiKeysModel apiKeys) {
    final candidates = <String>[];
    void addIfAvailable(String provider, String key) {
      if (primaryProvider != provider && key.trim().isNotEmpty) {
        candidates.add(provider);
      }
    }

    addIfAvailable(AppConstants.providerGroq, apiKeys.groqKey);
    addIfAvailable(AppConstants.providerGemini, apiKeys.geminiKey);
    addIfAvailable(AppConstants.providerOpenAi, apiKeys.openAiKey);
    addIfAvailable(AppConstants.providerAnthropic, apiKeys.anthropicKey);
    addIfAvailable(AppConstants.providerOpenRouter, apiKeys.openRouterKey);
    if (primaryProvider != AppConstants.providerLocal && apiKeys.localAiBaseUrl.trim().isNotEmpty) {
      candidates.add(AppConstants.providerLocal);
    }
    return candidates;
  }

  /// Core streaming pipeline with CancelToken, Auto-Fallback, and Sliding Window (N=20).
  Future<void> processTextQuery({
    required String userQuery,
    required List<ChatMessage> conversationHistory,
    required ApiKeysModel apiKeys,
    required PersonaModel persona,
    required VoiceConfigModel voiceConfig,
    VoiceConfiguration? characterVoiceConfig,
    bool enableVoicePlayback = true,
  }) async {
    await interrupt();

    _setStatus(PipelineStatus.thinking);
    _sentenceChunker.reset();
    _activeLlmCancelToken = CancelToken();

    final StringBuffer fullResponseBuffer = StringBuffer();
    final sanitizer = StreamResponseSanitizer();

    // Context Window Optimization (TASK 3): Cap history to maximum N=20 messages
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

    // Apply 20-message sliding window
    final slidingHistory = updatedHistory.length > 20
        ? updatedHistory.sublist(updatedHistory.length - 20)
        : updatedHistory;

    final effectiveSystemPrompt = buildEffectiveSystemPrompt(persona.systemPrompt);

    // Auto-Fallback Chain Setup (TASK 2)
    final providerChain = [
      apiKeys.selectedProvider,
      ..._buildFallbackCandidates(apiKeys.selectedProvider, apiKeys),
    ];

    await _executeStreamWithFallback(
      providerChain: providerChain,
      chainIndex: 0,
      history: slidingHistory,
      systemPrompt: effectiveSystemPrompt,
      apiKeys: apiKeys,
      voiceConfig: voiceConfig,
      characterVoiceConfig: characterVoiceConfig,
      enableVoicePlayback: enableVoicePlayback,
      fullResponseBuffer: fullResponseBuffer,
      sanitizer: sanitizer,
    );
  }

  /// Recursively executes the stream through the fallback chain if a network/rate-limit error occurs.
  Future<void> _executeStreamWithFallback({
    required List<String> providerChain,
    required int chainIndex,
    required List<ChatMessage> history,
    required String systemPrompt,
    required ApiKeysModel apiKeys,
    required VoiceConfigModel voiceConfig,
    VoiceConfiguration? characterVoiceConfig,
    required bool enableVoicePlayback,
    required StringBuffer fullResponseBuffer,
    required StreamResponseSanitizer sanitizer,
  }) async {
    if (chainIndex >= providerChain.length) {
      _setStatus(PipelineStatus.error);
      _notifyError('Tất cả các nhà cung cấp AI đã thiết lập đều gặp lỗi hoặc không khả dụng.');
      return;
    }

    final currentProviderName = providerChain[chainIndex];
    final currentApiKey = _getApiKeyForProvider(currentProviderName, apiKeys);

    if (currentApiKey.isEmpty) {
      // Skip if key is empty, try next
      return _executeStreamWithFallback(
        providerChain: providerChain,
        chainIndex: chainIndex + 1,
        history: history,
        systemPrompt: systemPrompt,
        apiKeys: apiKeys,
        voiceConfig: voiceConfig,
        characterVoiceConfig: characterVoiceConfig,
        enableVoicePlayback: enableVoicePlayback,
        fullResponseBuffer: fullResponseBuffer,
        sanitizer: sanitizer,
      );
    }

    if (chainIndex > 0) {
      _notifyFallback('Đã tự động chuyển sang ${currentProviderName.toUpperCase()} do nhà cung cấp trước gặp sự cố kết nối/hạn mức.');
    }

    final provider = llmFactory.getProvider(currentProviderName);
    final customUrl = currentProviderName == AppConstants.providerLocal
        ? apiKeys.localAiBaseUrl
        : apiKeys.openRouterBaseUrl;

    try {
      final tokenStream = provider.streamChat(
        history: history,
        systemPrompt: systemPrompt,
        apiKey: currentApiKey,
        model: (currentProviderName == apiKeys.selectedProvider) ? apiKeys.selectedModel : null,
        customBaseUrl: customUrl,
        cancelToken: _activeLlmCancelToken,
      );

      _streamTimeoutTimer?.cancel();
      _streamTimeoutTimer = Timer(const Duration(seconds: 45), () {
        if (_status == PipelineStatus.thinking) {
          _llmStreamSubscription?.cancel();
          _setStatus(PipelineStatus.error);
          _notifyError('Yêu cầu AI đã hết thời gian chờ phản hồi (Timeout).');
        }
      });

      _llmStreamSubscription = tokenStream.listen(
        (rawToken) {
          _streamTimeoutTimer?.cancel();
          final cleanTokens = sanitizer.processChunk(rawToken);
          for (final token in cleanTokens) {
            fullResponseBuffer.write(token);
            _notifyAiToken(fullResponseBuffer.toString());

            // Real-time sentence chunking for TTS
            if (enableVoicePlayback) {
              final completedSentences = _sentenceChunker.processToken(token);
              for (final sentence in completedSentences) {
                ttsQueueManager.enqueue(
                  sentence,
                  voiceConfig,
                  voiceConfig: characterVoiceConfig,
                  geminiApiKey: apiKeys.geminiKey,
                );
              }
            }
          }
        },
        onError: (e) async {
          _streamTimeoutTimer?.cancel();

          // If barge-in cancelled, do not fallback
          if (e is DioException && e.type == DioExceptionType.cancel) {
            return;
          }

          // If error happened before any tokens received, fallback to next provider in chain
          if (fullResponseBuffer.isEmpty && chainIndex + 1 < providerChain.length) {
            await _executeStreamWithFallback(
              providerChain: providerChain,
              chainIndex: chainIndex + 1,
              history: history,
              systemPrompt: systemPrompt,
              apiKeys: apiKeys,
              voiceConfig: voiceConfig,
              characterVoiceConfig: characterVoiceConfig,
              enableVoicePlayback: enableVoicePlayback,
              fullResponseBuffer: fullResponseBuffer,
              sanitizer: sanitizer,
            );
            return;
          }

          _setStatus(PipelineStatus.error);
          final cleanErr = NetworkLogger.formatUserMessage(
            e,
            service: currentProviderName,
            model: apiKeys.selectedModel,
          );
          _notifyError(cleanErr);
        },
        onDone: () {
          _streamTimeoutTimer?.cancel();

          final flushedToken = sanitizer.flush();
          if (flushedToken != null && flushedToken.isNotEmpty) {
            fullResponseBuffer.write(flushedToken);
            _notifyAiToken(fullResponseBuffer.toString());
            if (enableVoicePlayback) {
              final completedSentences = _sentenceChunker.processToken(flushedToken);
              for (final sentence in completedSentences) {
                ttsQueueManager.enqueue(
                  sentence,
                  voiceConfig,
                  voiceConfig: characterVoiceConfig,
                  geminiApiKey: apiKeys.geminiKey,
                );
              }
            }
          }

          if (enableVoicePlayback) {
            final remainder = _sentenceChunker.flush();
            if (remainder != null && remainder.isNotEmpty) {
              ttsQueueManager.enqueue(
                remainder,
                voiceConfig,
                voiceConfig: characterVoiceConfig,
                geminiApiKey: apiKeys.geminiKey,
              );
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
      if (fullResponseBuffer.isEmpty && chainIndex + 1 < providerChain.length) {
        await _executeStreamWithFallback(
          providerChain: providerChain,
          chainIndex: chainIndex + 1,
          history: history,
          systemPrompt: systemPrompt,
          apiKeys: apiKeys,
          voiceConfig: voiceConfig,
          characterVoiceConfig: characterVoiceConfig,
          enableVoicePlayback: enableVoicePlayback,
          fullResponseBuffer: fullResponseBuffer,
          sanitizer: sanitizer,
        );
        return;
      }
      _setStatus(PipelineStatus.error);
      final cleanErr = NetworkLogger.formatUserMessage(
        e,
        service: currentProviderName,
        model: apiKeys.selectedModel,
      );
      _notifyError(cleanErr);
    }
  }

  /// Cancels any active LLM stream and stops TTS playback immediately (< 50ms Barge-in).
  Future<void> interrupt() async {
    _streamTimeoutTimer?.cancel();
    _streamTimeoutTimer = null;
    _activeLlmCancelToken?.cancel('User barge-in interrupt');
    _activeLlmCancelToken = null;
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
    _fallbackNotificationController.close();
  }
}
