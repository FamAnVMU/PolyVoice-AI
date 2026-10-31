import 'dart:async';
import 'dart:collection';
import '../../features/settings/data/models/voice_config_model.dart';
import '../../features/voice/data/models/voice_configuration.dart';
import 'tts_service.dart';

/// Manages a FIFO queue of streaming sentences to eliminate latency:
/// as soon as the first complete sentence is parsed, it plays immediately
/// while subsequent tokens are still being streamed from the LLM.
class TtsQueueManager {
  final TtsService _ttsService;
  final Queue<String> _sentenceQueue = Queue<String>();
  VoiceConfigModel? _currentConfig;
  VoiceConfiguration? _currentVoiceConfig;
  String? _currentGeminiKey;
  bool _isProcessing = false;
  bool _isInterrupted = false;

  Function()? onQueueStarted;
  Function()? onQueueFinished;
  Function(String sentence)? onSentenceStarted;

  bool get isSpeaking => _isProcessing || _ttsService.isPlaying;

  TtsQueueManager(this._ttsService);

  /// Enqueues a new completed sentence for immediate or sequential speech playback.
  void enqueue(
    String sentence,
    VoiceConfigModel config, {
    VoiceConfiguration? voiceConfig,
    String? geminiApiKey,
  }) {
    final clean = sentence.trim();
    if (clean.isEmpty) return;

    _currentConfig = config;
    _currentVoiceConfig = voiceConfig;
    _currentGeminiKey = geminiApiKey;
    _sentenceQueue.add(clean);

    if (!_isProcessing) {
      _processQueue();
    }
  }

  Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;
    _isInterrupted = false;
    onQueueStarted?.call();

    while (_sentenceQueue.isNotEmpty && !_isInterrupted) {
      final sentence = _sentenceQueue.removeFirst();
      onSentenceStarted?.call(sentence);

      try {
        await _ttsService.speak(
          sentence,
          config: _currentConfig,
          voiceConfig: _currentVoiceConfig,
          geminiApiKey: _currentGeminiKey,
        );
      } catch (_) {
        // If one chunk fails, proceed to next
      }

      if (_isInterrupted) break;
    }

    _isProcessing = false;
    onQueueFinished?.call();
  }

  /// Stops current audio playback immediately and empties the sentence queue
  /// (e.g., when the user begins speaking or presses the interrupt button).
  Future<void> stopAndClear() async {
    _isInterrupted = true;
    _sentenceQueue.clear();
    await _ttsService.stop();
    _isProcessing = false;
    onQueueFinished?.call();
  }

  void dispose() {
    stopAndClear();
  }
}
