import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import '../../core/errors/failures.dart';
import '../../features/settings/data/models/voice_config_model.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isPlaying = false;
  Completer<void>? _currentSpeechCompleter;

  Function()? onStart;
  Function()? onCompletion;
  Function(String error)? onError;

  bool get isPlaying => _isPlaying;

  TtsService() {
    _initTts();
  }

  void _initTts() {
    _flutterTts.setStartHandler(() {
      _isPlaying = true;
      onStart?.call();
    });

    _flutterTts.setCompletionHandler(() {
      _isPlaying = false;
      onCompletion?.call();
      if (_currentSpeechCompleter != null && !_currentSpeechCompleter!.isCompleted) {
        _currentSpeechCompleter!.complete();
      }
    });

    _flutterTts.setCancelHandler(() {
      _isPlaying = false;
      if (_currentSpeechCompleter != null && !_currentSpeechCompleter!.isCompleted) {
        _currentSpeechCompleter!.complete();
      }
    });

    _flutterTts.setErrorHandler((msg) {
      _isPlaying = false;
      onError?.call(msg.toString());
      if (_currentSpeechCompleter != null && !_currentSpeechCompleter!.isCompleted) {
        _currentSpeechCompleter!.complete();
      }
    });
  }

  /// Applies voice configuration (pitch, rate, volume, language, and selected voice engine).
  Future<void> configureVoice(VoiceConfigModel config) async {
    try {
      await _flutterTts.setLanguage(config.languageCode);
      await _flutterTts.setPitch(config.pitch);
      await _flutterTts.setSpeechRate(config.rate);
      await _flutterTts.setVolume(config.volume);

      if (config.voiceName != null && config.voiceLocale != null) {
        await _flutterTts.setVoice({
          'name': config.voiceName!,
          'locale': config.voiceLocale!,
        });
      }
    } catch (e) {
      throw TtsFailure('Failed to configure TTS engine: $e');
    }
  }

  /// Speaks a sentence and returns a Future that completes when playback ends.
  Future<void> speak(String text, {VoiceConfigModel? config}) async {
    if (text.trim().isEmpty) return;

    if (config != null) {
      await configureVoice(config);
    }

    _currentSpeechCompleter = Completer<void>();
    _isPlaying = true;

    final result = await _flutterTts.speak(text);
    if (result == 1) {
      await _currentSpeechCompleter?.future;
    } else {
      _isPlaying = false;
    }
  }

  /// Stops current speech playback immediately.
  Future<void> stop() async {
    _isPlaying = false;
    await _flutterTts.stop();
    if (_currentSpeechCompleter != null && !_currentSpeechCompleter!.isCompleted) {
      _currentSpeechCompleter!.complete();
    }
  }

  /// Queries all available system voices on the device.
  Future<List<Map<String, String>>> getAvailableVoices({String? filterLanguageCode}) async {
    try {
      final dynamic rawVoices = await _flutterTts.getVoices;
      if (rawVoices is List) {
        final List<Map<String, String>> voices = [];
        for (final item in rawVoices) {
          if (item is Map) {
            final name = item['name']?.toString() ?? '';
            final locale = item['locale']?.toString() ?? '';
            if (name.isNotEmpty && locale.isNotEmpty) {
              if (filterLanguageCode != null && filterLanguageCode.isNotEmpty) {
                final prefix = filterLanguageCode.split('-').first.toLowerCase();
                if (!locale.toLowerCase().startsWith(prefix)) {
                  continue;
                }
              }
              voices.add({'name': name, 'locale': locale});
            }
          }
        }
        return voices;
      }
    } catch (_) {}
    return [];
  }

  /// Returns supported language codes on device.
  Future<List<String>> getSupportedLanguages() async {
    try {
      final dynamic rawLangs = await _flutterTts.getLanguages;
      if (rawLangs is List) {
        return rawLangs.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return ['vi-VN', 'en-US', 'ja-JP', 'ko-KR'];
  }

  void dispose() {
    _flutterTts.stop();
  }
}
