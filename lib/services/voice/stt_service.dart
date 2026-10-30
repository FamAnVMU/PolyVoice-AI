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
import '../../core/network/network_logger.dart';

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
                connectTimeout: const Duration(seconds: 20),
                sendTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 30),
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
          // Filter out transient silence timeouts from surfacing as fatal errors
          final msg = val.errorMsg.toLowerCase();
          if (msg.contains('no_match') || msg.contains('speech_timeout') || msg.contains('busy')) {
            return;
          }
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
      NetworkLogger.logError(
        service: 'NativeSTT',
        endpoint: 'on-device-engine',
        error: e,
      );
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
      throw const PermissionFailure('Quyền Microphone chưa được cấp. Vui lòng cấp quyền trong Cài đặt thiết bị.');
    }

    _lastRecognizedWords = '';
    _isListening = true;
    _activeMode = mode;

    if (_activeMode == AppConstants.sttModeOnDevice) {
      final initialized = await initializeNativeStt(onError: onError);
      if (!initialized) {
        // Transparent fallback to Groq Whisper if on-device STT is unavailable
        if (groqApiKey != null && groqApiKey.trim().isNotEmpty) {
          _activeMode = AppConstants.sttModeGroqWhisper;
          await _startWhisperRecording();
          return;
        }
        _isListening = false;
        throw const SttFailure('Bộ nhận diện giọng nói cục bộ không khả dụng trên thiết bị. Bạn có thể bật Mode B: Groq Whisper trong Cài đặt.');
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
        throw SttFailure('Lỗi khi lắng nghe giọng nói: $e');
      }
    } else {
      // Mode B: Groq Whisper API recording
      if (groqApiKey == null || groqApiKey.trim().isEmpty) {
        _isListening = false;
        throw const ApiKeyFailure('Cần có Groq Cloud API Key để sử dụng chế độ Whisper. Vui lòng thiết lập trong Cài đặt.');
      }
      await _startWhisperRecording();
    }
  }

  Future<void> _startWhisperRecording() async {
    final tempDir = await getTemporaryDirectory();
    _currentRecordingPath = '${tempDir.path}/polyvoice_stt_${DateTime.now().millisecondsSinceEpoch}.m4a';

    const config = RecordConfig(
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
        throw const ApiKeyFailure('Thiếu Groq API Key để chuyển đổi âm thanh thành văn bản.');
      }

      final stopwatch = Stopwatch()..start();
      NetworkLogger.logRequest(
        service: 'GroqWhisper',
        endpoint: ApiEndpoints.groqAudioTranscriptions,
      );

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
            sendTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
          ),
        );

        NetworkLogger.logResponse(
          service: 'GroqWhisper',
          endpoint: ApiEndpoints.groqAudioTranscriptions,
          statusCode: response.statusCode ?? 200,
          durationMs: stopwatch.elapsedMilliseconds,
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
        NetworkLogger.logError(
          service: 'GroqWhisper',
          endpoint: ApiEndpoints.groqAudioTranscriptions,
          error: detail,
          statusCode: e.response?.statusCode,
          durationMs: stopwatch.elapsedMilliseconds,
        );

        if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
          throw const NetworkFailure('Hết thời gian chờ nhận diện giọng nói từ Groq Whisper (Timeout).');
        } else if (e.type == DioExceptionType.connectionError) {
          throw const NetworkFailure('Không thể kết nối đến máy chủ Groq Whisper. Vui lòng kiểm tra Internet.');
        }
        throw SttFailure('Lỗi nhận diện âm thanh qua Whisper: $detail');
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
