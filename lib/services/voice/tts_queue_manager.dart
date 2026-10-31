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
  int _epoch = 0;

  final List<void Function()> _finishedListeners = [];

  void addFinishedListener(void Function() listener) {
    if (!_finishedListeners.contains(listener)) {
      _finishedListeners.add(listener);
    }
  }

  void removeFinishedListener(void Function() listener) {
    _finishedListeners.remove(listener);
  }

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
    final int currentEpoch = _epoch;
    onQueueStarted?.call();

    while (_sentenceQueue.isNotEmpty && currentEpoch == _epoch) {
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

      if (currentEpoch != _epoch) break;
    }

    if (currentEpoch == _epoch) {
      _isProcessing = false;
      _notifyFinished();
    }
  }

  void _notifyFinished() {
    onQueueFinished?.call();
    for (final listener in List<void Function()>.from(_finishedListeners)) {
      listener();
    }
  }

  /// Stops current audio playback immediately and empties the sentence queue
  /// (e.g., when the user begins speaking or presses the interrupt button).
  Future<void> stopAndClear() async {
    _epoch++;
    _sentenceQueue.clear();
    await _ttsService.stop();
    _isProcessing = false;
    _notifyFinished();
  }

  void dispose() {
    stopAndClear();
    _finishedListeners.clear();
  }
}
