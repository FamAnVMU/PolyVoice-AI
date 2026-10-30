import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/vietnamese_text_normalizer.dart';
import '../../features/settings/data/models/voice_config_model.dart';
import '../../features/voice/data/models/voice_model.dart';
import '../../features/voice/data/preset_voices.dart';
import 'elevenlabs_service.dart';
import 'native_media_service.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  final NativeMediaService _nativeMediaService = NativeMediaService();
  final ElevenLabsService _elevenLabsService = ElevenLabsService();

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

  /// Configures local TTS synthesis parameters with conversational pacing
  Future<void> configureVoice(VoiceConfigModel config, {VoiceModel? activeVoice}) async {
    try {
      await _flutterTts.setLanguage(config.languageCode);

      // Modulate pitch & rate using the active voice persona's default characteristics
      double effectivePitch = config.pitch;
      double effectiveRate = config.rate;

      if (activeVoice != null) {
        effectivePitch = activeVoice.defaultPitch * (config.pitch / AppConstants.defaultPitch);
        effectiveRate = activeVoice.defaultSpeed * (config.rate / AppConstants.defaultRate);
      }

      // Clamp to natural human vocal ranges
      await _flutterTts.setPitch(effectivePitch.clamp(0.5, 2.0));
      // In FlutterTts, 0.45 - 0.50 on Android corresponds to ~0.85x - 0.90x human conversational speech
      await _flutterTts.setSpeechRate((effectiveRate * 0.50).clamp(0.2, 1.0));
      await _flutterTts.setVolume(config.volume.clamp(0.0, 1.0));

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

  /// Speaks text with Vietnamese human-like normalization and voice engine routing.
  Future<void> speak(
    String rawText, {
    VoiceConfigModel? config,
    VoiceModel? voice,
    List<VoiceModel>? customVoices,
  }) async {
    final cleanText = rawText.trim();
    if (cleanText.isEmpty) return;

    // 1. Normalize text into natural spoken Vietnamese (expand acronyms, numbers, dates, pauses)
    final normalizedText = VietnameseTextNormalizer.normalize(cleanText);

    final effectiveConfig = config ?? const VoiceConfigModel();

    // 2. Resolve active VoiceModel
    VoiceModel? activeVoice = voice;
    if (activeVoice == null) {
      final voiceId = effectiveConfig.selectedVoiceId;
      if (customVoices != null && customVoices.isNotEmpty) {
        activeVoice = customVoices.cast<VoiceModel?>().firstWhere(
              (v) => v?.id == voiceId,
              orElse: () => null,
            );
      }
      activeVoice ??= PresetVoices.findById(voiceId);
    }

    _currentSpeechCompleter = Completer<void>();
    _isPlaying = true;
    onStart?.call();

    // 3. Check if voice uses ElevenLabs Cloud Voice Cloning
    final isElevenLabs = activeVoice.engineType == 'elevenlabs' ||
        effectiveConfig.voiceEngine == AppConstants.voiceEngineElevenLabs;
    final apiKey = effectiveConfig.elevenLabsApiKey.trim();

    if (isElevenLabs && activeVoice.remoteVoiceId != null && apiKey.isNotEmpty) {
      try {
        final audioPath = await _elevenLabsService.synthesizeSpeech(
          text: normalizedText,
          voiceId: activeVoice.remoteVoiceId!,
          apiKey: apiKey,
          stability: effectiveConfig.stability,
          style: effectiveConfig.style,
        );

        await _nativeMediaService.playAudio(
          audioPath,
          onCompleted: () {
            _isPlaying = false;
            onCompletion?.call();
            if (_currentSpeechCompleter != null && !_currentSpeechCompleter!.isCompleted) {
              _currentSpeechCompleter!.complete();
            }
          },
        );
        return;
      } catch (e) {
        // Fallback to Enhanced Device Voice Engine on cloud error
        onError?.call('ElevenLabs voice unavailable, falling back to Enhanced Device Voice.');
      }
    }

    // 4. Enhanced Device Engine (Local TTS with Vietnamese Normalization & Human Pacing)
    try {
      await configureVoice(effectiveConfig, activeVoice: activeVoice);
      final result = await _flutterTts.speak(normalizedText);
      if (result == 1) {
        await _currentSpeechCompleter?.future;
      } else {
        _isPlaying = false;
      }
    } catch (e) {
      _isPlaying = false;
      onError?.call('TTS error: $e');
      if (_currentSpeechCompleter != null && !_currentSpeechCompleter!.isCompleted) {
        _currentSpeechCompleter!.complete();
      }
    }
  }

  /// Stops current speech playback immediately across both local and native audio players.
  Future<void> stop() async {
    _isPlaying = false;
    try {
      await _flutterTts.stop();
    } catch (_) {}
    try {
      await _nativeMediaService.stopAudio();
    } catch (_) {}

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
    stop();
  }
}
