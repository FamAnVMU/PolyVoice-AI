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
  final Dio _dio = Dio();

  bool _isNativeInitialized = false;
  bool _isListening = false;
  String? _currentRecordingPath;

  bool get isListening => _isListening;

  /// Request microphone and speech recognition permissions.
  Future<bool> checkAndRequestPermissions() async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      return false;
    }

    final speechStatus = await Permission.speech.request();
    return speechStatus.isGranted || speechStatus.isLimited;
  }

  /// Initialize native on-device speech recognizer.
  Future<bool> initializeNativeStt() async {
    if (_isNativeInitialized) return true;

    try {
      _isNativeInitialized = await _speechToText.initialize(
        onError: (val) => _isListening = false,
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            _isListening = false;
          }
        },
      );
      return _isNativeInitialized;
    } catch (_) {
      return false;
    }
  }

  /// Start listening using selected STT mode.
  Future<void> startListening({
    required String mode,
    required String languageCode,
    required Function(String text, bool isFinal) onResult,
    String? groqApiKey,
  }) async {
    final hasPermission = await checkAndRequestPermissions();
    if (!hasPermission) {
      throw const PermissionFailure('Microphone or Speech permission was denied.');
    }

    _isListening = true;

    if (mode == AppConstants.sttModeOnDevice) {
      final initialized = await initializeNativeStt();
      if (!initialized) {
        _isListening = false;
        throw const SttFailure('Failed to initialize on-device speech engine.');
      }

      await _speechToText.listen(
        onResult: (result) {
          onResult(result.recognizedWords, result.finalResult);
          if (result.finalResult) {
            _isListening = false;
          }
        },
        localeId: languageCode,
        listenMode: stt.ListenMode.confirmation,
        cancelOnError: true,
        partialResults: true,
      );
    } else {
      // Mode B: Groq Whisper API recording
      if (groqApiKey == null || groqApiKey.isEmpty) {
        _isListening = false;
        throw const ApiKeyFailure('Groq API Key is required for Groq Whisper Mode.');
      }

      final tempDir = await getTemporaryDirectory();
      _currentRecordingPath = '${tempDir.path}/polyvoice_stt_${DateTime.now().millisecondsSinceEpoch}.m4a';

      final config = const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      );

      await _audioRecorder.start(config, path: _currentRecordingPath!);
    }
  }

  /// Stop listening and, if using Groq Whisper, transcribe recorded audio.
  Future<String?> stopListening({
    required String mode,
    String? groqApiKey,
    String? languageCode,
  }) async {
    if (!_isListening) return null;
    _isListening = false;

    if (mode == AppConstants.sttModeOnDevice) {
      await _speechToText.stop();
      return null;
    } else {
      // Mode B: Stop recording and send audio to Groq Whisper API
      final path = await _audioRecorder.stop();
      if (path == null) return null;

      final file = File(path);
      if (!await file.exists()) return null;

      if (groqApiKey == null || groqApiKey.isEmpty) {
        throw const ApiKeyFailure('Groq API Key is missing for Whisper transcription.');
      }

      try {
        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(path, filename: 'audio.m4a'),
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
              'Authorization': 'Bearer $groqApiKey',
            },
          ),
        );

        if (response.statusCode == 200 && response.data != null) {
          final text = response.data['text'] as String?;
          return text?.trim();
        }
        return null;
      } on DioException catch (e) {
        throw SttFailure('Groq Whisper transcription failed: ${e.message}');
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
    _speechToText.stop();
    _audioRecorder.dispose();
  }
}
