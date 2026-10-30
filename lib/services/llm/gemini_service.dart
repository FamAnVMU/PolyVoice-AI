import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/failures.dart';
import '../../features/chat/data/models/chat_message.dart';
import 'llm_provider.dart';

class GeminiService implements LlmProvider {
  final Dio _dio;

  GeminiService({Dio? dio}) : _dio = dio ?? Dio();

  @override
  String get providerName => AppConstants.providerGemini;

  @override
  Stream<String> streamChat({
    required List<ChatMessage> history,
    required String systemPrompt,
    required String apiKey,
    String? model,
    String? customBaseUrl,
  }) async* {
    if (apiKey.isEmpty) {
      throw const ApiKeyFailure('Google Gemini API Key is missing. Please set it in Settings.');
    }

    final targetModel = model ?? AppConstants.defaultGeminiModel;
    final url = ApiEndpoints.geminiStream(targetModel, apiKey);

    // Format Gemini history payload
    final List<Map<String, dynamic>> contents = [];
    for (final msg in history) {
      if (msg.content.trim().isEmpty) continue;
      contents.add({
        'role': msg.isUser ? 'user' : 'model',
        'parts': [
          {'text': msg.content}
        ],
      });
    }

    final Map<String, dynamic> body = {
      'system_instruction': {
        'parts': [
          {'text': systemPrompt}
        ],
      },
      'contents': contents,
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 2048,
      },
    };

    Response<ResponseBody> response;
    try {
      response = await _dio.post<ResponseBody>(
        url,
        data: body,
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Content-Type': 'application/json'},
        ),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 400 || e.response?.statusCode == 403) {
        throw ApiKeyFailure('Invalid Gemini API Key or restricted permissions: ${e.message}');
      } else if (e.response?.statusCode == 429) {
        throw const RateLimitFailure('Gemini API rate limit reached. Please wait a moment.');
      }
      throw NetworkFailure('Network error connecting to Gemini: ${e.message}');
    }

    final stream = response.data?.stream;
    if (stream == null) {
      throw const NetworkFailure('Empty response stream received from Gemini API.');
    }

    // SSE Stream line parser
    final lineStream = stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lineStream) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('data: ')) {
        final dataStr = trimmed.substring(6).trim();
        if (dataStr == '[DONE]') break;

        try {
          final jsonMap = jsonDecode(dataStr) as Map<String, dynamic>;
          final candidates = jsonMap['candidates'] as List<dynamic>?;
          if (candidates != null && candidates.isNotEmpty) {
            final firstCandidate = candidates.first as Map<String, dynamic>;
            final content = firstCandidate['content'] as Map<String, dynamic>?;
            final parts = content?['parts'] as List<dynamic>?;
            if (parts != null && parts.isNotEmpty) {
              final firstPart = parts.first as Map<String, dynamic>;
              final String? text = firstPart['text'] as String?;
              if (text != null && text.isNotEmpty) {
                yield text;
              }
            }
          }
        } catch (_) {
          // Skip malformed SSE chunks
        }
      }
    }
  }

  @override
  Future<bool> testConnection({
    required String apiKey,
    String? model,
    String? customBaseUrl,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.geminiPing(apiKey),
        options: Options(
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      if (e.response?.statusCode == 400 || e.response?.statusCode == 403) {
        throw const ApiKeyFailure('Invalid Gemini API key.');
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
