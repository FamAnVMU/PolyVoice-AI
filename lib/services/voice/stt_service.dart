import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/failures.dart';

class SttService {
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final Dio _dio;

  bool _isNativeInitialized = false;
  bool _isListening = false;
  String? _currentRecordingPath;
  String _activeMode = AppConstants.sttModeOnDevice;
  String _lastRecognizedWords = '';

  bool get isListening => _isListening;
  String get activeMode => _activeMode;

  SttService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                sendTimeout: const Duration(seconds: 25),
                receiveTimeout: const Duration(seconds: 25),
              ),
            );

  /// Request microphone and speech recognition permissions.
  Future<bool> checkAndRequestPermissions() async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      return false;
    }

    if (Platform.isAndroid) {
      // On Android, RECORD_AUDIO (microphone) is the necessary runtime permission.
      return micStatus.isGranted;
    }

    final speechStatus = await Permission.speech.request();
    return speechStatus.isGranted || speechStatus.isLimited;
  }

  /// Initialize native on-device speech recognizer.
  Future<bool> initializeNativeStt({Function(String error)? onError}) async {
    if (_isNativeInitialized) return true;

    try {
      _isNativeInitialized = await _speechToText.initialize(
        onError: (val) {
          _isListening = false;
          onError?.call(val.errorMsg);
        },
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            _isListening = false;
          }
        },
      );
      return _isNativeInitialized;
    } catch (e) {
      onError?.call(e.toString());
      return false;
    }
  }

  /// Start listening using selected STT mode.
  Future<void> startListening({
    required String mode,
    required String languageCode,
    required Function(String text, bool isFinal) onResult,
    Function(String error)? onError,
    String? groqApiKey,
  }) async {
    final hasPermission = await checkAndRequestPermissions();
    if (!hasPermission) {
      throw const PermissionFailure('Microphone permission was denied. Please grant microphone access in device settings.');
    }

    _lastRecognizedWords = '';
    _isListening = true;
    _activeMode = mode;

    if (_activeMode == AppConstants.sttModeOnDevice) {
      final initialized = await initializeNativeStt(onError: onError);
      if (!initialized) {
        // Fallback to Groq Whisper if on-device STT is unavailable on this device
        if (groqApiKey != null && groqApiKey.trim().isNotEmpty) {
          _activeMode = AppConstants.sttModeGroqWhisper;
          await _startWhisperRecording();
          return;
        }
        _isListening = false;
        throw const SttFailure('On-device speech engine could not be initialized. Please configure Groq Whisper mode in Settings.');
      }

      try {
        await _speechToText.listen(
          onResult: (result) {
            _lastRecognizedWords = result.recognizedWords;
            onResult(result.recognizedWords, result.finalResult);
            if (result.finalResult) {
              _isListening = false;
            }
          },
          localeId: languageCode,
          listenMode: stt.ListenMode.confirmation,
          cancelOnError: false,
          partialResults: true,
        );
      } catch (e) {
        if (groqApiKey != null && groqApiKey.trim().isNotEmpty) {
          _activeMode = AppConstants.sttModeGroqWhisper;
          await _startWhisperRecording();
          return;
        }
        _isListening = false;
        throw SttFailure('On-device speech listening failed: $e');
      }
    } else {
      // Mode B: Groq Whisper API recording
      if (groqApiKey == null || groqApiKey.trim().isEmpty) {
        _isListening = false;
        throw const ApiKeyFailure('Groq Cloud API Key is required for Groq Whisper Mode. Please set it in Settings.');
      }
      await _startWhisperRecording();
    }
  }

  Future<void> _startWhisperRecording() async {
    final tempDir = await getTemporaryDirectory();
    _currentRecordingPath = '${tempDir.path}/polyvoice_stt_${DateTime.now().millisecondsSinceEpoch}.m4a';

    final config = const RecordConfig(
      encoder: AudioEncoder.aacLc,
      bitRate: 128000,
      sampleRate: 44100,
    );

    await _audioRecorder.start(config, path: _currentRecordingPath!);
  }

  /// Stop listening and, if using Groq Whisper, transcribe recorded audio.
  Future<String?> stopListening({
    required String mode,
    String? groqApiKey,
    String? languageCode,
  }) async {
    if (!_isListening) return null;
    _isListening = false;

    if (_activeMode == AppConstants.sttModeOnDevice) {
      try {
        await _speechToText.stop();
      } catch (_) {}
      final recognized = _lastRecognizedWords.trim();
      _lastRecognizedWords = '';
      return recognized.isNotEmpty ? recognized : null;
    } else {
      // Mode B: Stop recording and send audio to Groq Whisper API
      final path = await _audioRecorder.stop();
      if (path == null) return null;

      final file = File(path);
      if (!await file.exists() || await file.length() == 0) {
        return null;
      }

      final cleanGroqKey = (groqApiKey ?? '').trim();
      if (cleanGroqKey.isEmpty) {
        throw const ApiKeyFailure('Groq API Key is missing for Whisper transcription.');
      }

      try {
        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(
            path,
            filename: 'audio.m4a',
            contentType: DioMediaType('audio', 'm4a'),
          ),
          'model': 'whisper-large-v3',
          'response_format': 'json',
          if (languageCode != null && languageCode.length >= 2)
            'language': languageCode.substring(0, 2).toLowerCase(),
        });

        final response = await _dio.post(
          ApiEndpoints.groqAudioTranscriptions,
          data: formData,
          options: Options(
            headers: {
              'Authorization': 'Bearer $cleanGroqKey',
            },
            sendTimeout: const Duration(seconds: 25),
            receiveTimeout: const Duration(seconds: 25),
          ),
        );

        if (response.statusCode == 200 && response.data != null) {
          final text = response.data['text'] as String?;
          return text?.trim();
        }
        return null;
      } on DioException catch (e) {
        String detail = e.message ?? e.toString();
        if (e.response?.data is Map) {
          detail = e.response?.data['error']?['message']?.toString() ?? detail;
        }
        if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
          throw const NetworkFailure('Timeout during voice transcription. Please check your connection.');
        } else if (e.type == DioExceptionType.connectionError) {
          throw const NetworkFailure('Cannot connect to Groq Whisper servers. Please check your internet connection.');
        }
        throw SttFailure('Groq Whisper transcription failed: $detail');
      } finally {
        try {
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
      }
    }
  }

  /// Cancels listening immediately.
  Future<void> cancel() async {
    _isListening = false;
    _lastRecognizedWords = '';
    try {
      await _speechToText.cancel();
    } catch (_) {}
    try {
      if (await _audioRecorder.isRecording()) {
        final path = await _audioRecorder.stop();
        if (path != null) {
          final file = File(path);
          if (await file.exists()) await file.delete();
        }
      }
    } catch (_) {}
  }

  void dispose() {
    cancel();
    _speechToText.stop();
    _audioRecorder.dispose();
  }
}
