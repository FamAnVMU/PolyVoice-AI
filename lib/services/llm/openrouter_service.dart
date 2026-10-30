import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/failures.dart';
import '../../features/chat/data/models/chat_message.dart';
import 'llm_provider.dart';

class OpenRouterService implements LlmProvider {
  final Dio _dio;

  OpenRouterService({Dio? dio}) : _dio = dio ?? Dio();

  @override
  String get providerName => AppConstants.providerOpenRouter;

  @override
  Stream<String> streamChat({
    required List<ChatMessage> history,
    required String systemPrompt,
    required String apiKey,
    String? model,
    String? customBaseUrl,
  }) async* {
    if (apiKey.isEmpty) {
      throw const ApiKeyFailure('OpenRouter API Key is missing. Please set it in Settings.');
    }

    final targetModel = model ?? AppConstants.defaultOpenRouterModel;
    final baseUrl = (customBaseUrl != null && customBaseUrl.trim().isNotEmpty)
        ? customBaseUrl.trim()
        : ApiEndpoints.defaultOpenRouterBaseUrl;

    final normalizedBaseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final endpoint = '$normalizedBaseUrl/chat/completions';

    final List<Map<String, String>> messages = [
      {'role': 'system', 'content': systemPrompt},
    ];

    for (final msg in history) {
      if (msg.content.trim().isEmpty) continue;
      messages.add({
        'role': msg.isUser ? 'user' : 'assistant',
        'content': msg.content,
      });
    }

    final Map<String, dynamic> body = {
      'model': targetModel,
      'messages': messages,
      'stream': true,
      'temperature': 0.7,
      'max_tokens': 2048,
    };

    Response<ResponseBody> response;
    try {
      response = await _dio.post<ResponseBody>(
        endpoint,
        data: body,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'Authorization': 'Bearer $apiKey',
            'HTTP-Referer': 'https://polyvoice.ai',
            'X-Title': 'PolyVoice AI',
            'Content-Type': 'application/json',
          },
        ),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const ApiKeyFailure('Invalid OpenRouter / OpenAI Key.');
      } else if (e.response?.statusCode == 429) {
        throw const RateLimitFailure('Rate limit reached on OpenRouter.');
      }
      throw NetworkFailure('Network error connecting to OpenRouter: ${e.message}');
    }

    final stream = response.data?.stream;
    if (stream == null) {
      throw const NetworkFailure('Empty response stream received from OpenRouter API.');
    }

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
          final choices = jsonMap['choices'] as List<dynamic>?;
          if (choices != null && choices.isNotEmpty) {
            final firstChoice = choices.first as Map<String, dynamic>;
            final delta = firstChoice['delta'] as Map<String, dynamic>?;
            final content = delta?['content'] as String?;
            if (content != null && content.isNotEmpty) {
              yield content;
            }
          }
        } catch (_) {
          // Ignore partial or unparseable SSE chunks
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
    final baseUrl = (customBaseUrl != null && customBaseUrl.trim().isNotEmpty)
        ? customBaseUrl.trim()
        : ApiEndpoints.defaultOpenRouterBaseUrl;

    final normalizedBaseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final endpoint = '$normalizedBaseUrl/models';

    try {
      final response = await _dio.get(
        endpoint,
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'HTTP-Referer': 'https://polyvoice.ai',
            'X-Title': 'PolyVoice AI',
          },
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const ApiKeyFailure('Invalid API key.');
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
