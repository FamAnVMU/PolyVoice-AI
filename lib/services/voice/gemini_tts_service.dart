import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/errors/failures.dart';
import '../../core/network/network_logger.dart';

/// Neural Text-to-Speech synthesis service powered by Google Gemini Studio Audio.
///
/// Produces ultra-realistic, expressive human-like speech for Vietnamese and multilingual text
/// using prebuilt studio voices:
/// - Aoede (Breezy, melodic, emotional female - ideal for Khánh Linh & Thảo Nhi)
/// - Kore (Firm, crisp, professional female - ideal for Ngọc Anh & Hoàng Yến)
/// - Charon (Deep, resonant, informative male - ideal for Minh An)
/// - Puck (Upbeat, friendly, conversational male - ideal for Gia Huy & Alex)
/// - Fenrir (Passionate, authentic male - ideal for Quốc Bảo)
class GeminiTtsService {
  final Dio _dio;

  GeminiTtsService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                sendTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 40),
              ),
            );

  /// Synthesizes [text] into an audio file path using Gemini Audio generation.
  /// Automatically uses disk caching to provide instantaneous subsequent playback.
  Future<String> synthesizeSpeech({
    required String text,
    required String voiceName, // 'Aoede', 'Kore', 'Puck', 'Charon', 'Fenrir'
    required String apiKey,
    String emotion = 'natural',
    double speed = 1.0,
    double pitch = 1.0,
  }) async {
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) {
      throw const ApiKeyFailure('Gemini API Key is required for Studio Neural TTS.');
    }

    final cleanText = text.trim();
    if (cleanText.isEmpty) {
      throw const TtsFailure('Text for speech synthesis cannot be empty.');
    }

    // 1. Check disk cache
    final tempDir = await getTemporaryDirectory();
    final cacheKey = md5.convert(utf8.encode('$voiceName-$emotion-$speed-$pitch-$cleanText')).toString();
    final cacheFile = File('${tempDir.path}/gemini_tts_$cacheKey.mp3');

    if (await cacheFile.exists() && await cacheFile.length() > 500) {
      return cacheFile.path;
    }

    // 2. Prepare emotion direction prompt for natural prosody
    String emotionInstruction = 'với ngữ điệu tự nhiên, chân thật và truyền cảm';
    switch (emotion) {
      case 'cheerful':
        emotionInstruction = 'với giọng điệu tươi vui, thân thiện, tràn đầy năng lượng tích cực';
        break;
      case 'calm':
        emotionInstruction = 'với giọng điệu điềm tĩnh, ấm áp, sâu lắng và thư giãn';
        break;
      case 'empathetic':
        emotionInstruction = 'với giọng điệu dịu dàng, thấu hiểu, chân thành và ân cần';
        break;
      case 'serious':
      case 'explanatory':
        emotionInstruction = 'với giọng điệu rõ ràng, dứt khoát, rành mạch từng từ, nhấn mạnh ý quan trọng';
        break;
      case 'storytelling':
        emotionInstruction = 'với phong cách kể chuyện truyền cảm, nhịp điệu giàu cảm xúc, có khoảng nghỉ tự nhiên';
        break;
      case 'excited':
        emotionInstruction = 'với phong thái hào hứng, phấn khởi và nhiệt huyết';
        break;
    }

    final prompt =
        'Đọc đoạn văn bản tiếng Việt sau đây $emotionInstruction. '
        'Chỉ phát âm nội dung văn bản một cách tự nhiên nhất như con người trò chuyện thực tế, '
        'tuyệt đối không thêm bất kỳ lời bình luận hay giải thích nào:\n\n$cleanText';

    final endpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$cleanKey';

    final requestBody = {
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'responseModalities': ['AUDIO'],
        'speechConfig': {
          'voiceConfig': {
            'prebuiltVoiceConfig': {
              'voiceName': voiceName,
            }
          }
        }
      }
    };

    final stopwatch = Stopwatch()..start();
    NetworkLogger.logRequest(
      service: 'GeminiTTS',
      endpoint: endpoint,
    );

    try {
      final response = await _dio.post(
        endpoint,
        data: requestBody,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': cleanKey,
          },
        ),
      );

      NetworkLogger.logResponse(
        service: 'GeminiTTS',
        endpoint: endpoint,
        statusCode: response.statusCode ?? 200,
        durationMs: stopwatch.elapsedMilliseconds,
      );

      if (response.statusCode == 200 && response.data != null) {
        final candidates = response.data['candidates'] as List<dynamic>?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates.first['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List<dynamic>?;
          if (parts != null && parts.isNotEmpty) {
            final inlineData = parts.first['inlineData'] as Map<String, dynamic>?;
            if (inlineData != null) {
              final base64Audio = inlineData['data'] as String?;
              if (base64Audio != null && base64Audio.isNotEmpty) {
                final audioBytes = base64Decode(base64Audio);
                await cacheFile.writeAsBytes(audioBytes, flush: true);
                return cacheFile.path;
              }
            }
          }
        }
      }

      throw const TtsFailure('Gemini API did not return valid audio payload.');
    } on DioException catch (e) {
      String detail = e.message ?? e.toString();
      if (e.response?.data is Map) {
        detail = e.response?.data['error']?['message']?.toString() ?? detail;
      }

      NetworkLogger.logError(
        service: 'GeminiTTS',
        endpoint: endpoint,
        error: detail,
        statusCode: e.response?.statusCode,
        durationMs: stopwatch.elapsedMilliseconds,
      );

      throw TtsFailure('Gemini TTS synthesis failed: $detail');
    } catch (e) {
      NetworkLogger.logError(
        service: 'GeminiTTS',
        endpoint: endpoint,
        error: e,
        durationMs: stopwatch.elapsedMilliseconds,
      );
      throw TtsFailure('Unexpected error during Gemini TTS synthesis: $e');
    }
  }
}
