import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/errors/failures.dart';
import '../../features/voice/data/models/voice_model.dart';

class ElevenLabsService {
  final Dio _dio;

  ElevenLabsService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://api.elevenlabs.io/v1',
                connectTimeout: const Duration(seconds: 15),
                sendTimeout: const Duration(seconds: 45),
                receiveTimeout: const Duration(seconds: 45),
              ),
            );

  /// Tests whether the ElevenLabs API Key is active and valid.
  Future<bool> testConnection(String apiKey) async {
    final clean = apiKey.trim();
    if (clean.isEmpty) return false;
    try {
      final res = await _dio.get(
        '/user',
        options: Options(
          headers: {'xi-api-key': clean},
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Clones a user's voice instantly from an imported reference audio file.
  Future<String> cloneVoice({
    required String name,
    required String description,
    required File audioFile,
    required String apiKey,
  }) async {
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) {
      throw const ApiKeyFailure('ElevenLabs API Key is missing. Please set it in Settings.');
    }

    if (!await audioFile.exists()) {
      throw const StorageFailure('Audio reference file not found on device.');
    }

    try {
      final ext = audioFile.path.split('.').last.toLowerCase();
      final formData = FormData.fromMap({
        'name': name.trim(),
        'description': description.trim(),
        'files': await MultipartFile.fromFile(
          audioFile.path,
          filename: 'reference.$ext',
          contentType: DioMediaType('audio', ext == 'mp3' ? 'mpeg' : ext),
        ),
        'labels': '{"language": "vi", "source": "PolyVoice_AI_Clone"}',
      });

      final response = await _dio.post(
        '/voices/add',
        data: formData,
        options: Options(
          headers: {'xi-api-key': cleanKey},
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final voiceId = response.data['voice_id'] as String?;
        if (voiceId != null && voiceId.isNotEmpty) {
          return voiceId;
        }
      }
      throw const TtsFailure('Không nhận được mã voice_id từ máy chủ ElevenLabs.');
    } on DioException catch (e) {
      final msg = e.response?.data?['detail']?['message'] ?? e.message;
      throw TtsFailure('Tạo giọng nói thất bại: $msg');
    }
  }

  /// Synthesizes speech using a cloned voice and returns the path to the cached MP3 file.
  Future<String> synthesizeSpeech({
    required String text,
    required String voiceId,
    required String apiKey,
    double stability = 0.5,
    double similarityBoost = 0.8,
    double style = 0.2,
  }) async {
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) {
      throw const ApiKeyFailure('ElevenLabs API Key is missing.');
    }

    try {
      final response = await _dio.post<List<int>>(
        '/text-to-speech/$voiceId',
        data: {
          'text': text,
          'model_id': 'eleven_multilingual_v2',
          'voice_settings': {
            'stability': stability.clamp(0.0, 1.0),
            'similarity_boost': similarityBoost.clamp(0.0, 1.0),
            'style': style.clamp(0.0, 1.0),
            'use_speaker_boost': true,
          },
        },
        options: Options(
          headers: {
            'xi-api-key': cleanKey,
            'Content-Type': 'application/json',
          },
          responseType: ResponseType.bytes,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final tempDir = await getTemporaryDirectory();
        final outFile = File(
          '${tempDir.path}/tts_eleven_${DateTime.now().millisecondsSinceEpoch}.mp3',
        );
        await outFile.writeAsBytes(response.data!);
        return outFile.path;
      }
      throw const TtsFailure('Không nhận được dữ liệu âm thanh từ ElevenLabs.');
    } on DioException catch (e) {
      final msg = e.response?.data?['detail']?['message'] ?? e.message;
      throw TtsFailure('Lỗi tạo giọng nói ElevenLabs: $msg');
    }
  }

  /// Deletes a cloned voice from the user's ElevenLabs account.
  Future<bool> deleteVoice({required String voiceId, required String apiKey}) async {
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) return false;
    try {
      final res = await _dio.delete(
        '/voices/$voiceId',
        options: Options(headers: {'xi-api-key': cleanKey}),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
