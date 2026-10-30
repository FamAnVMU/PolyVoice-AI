import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/failures.dart';
import '../../features/chat/data/models/chat_message.dart';
import 'llm_provider.dart';

class OpenRouterService implements LlmProvider {
  final Dio _dio;

  OpenRouterService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                sendTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 35),
              ),
            );

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
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) {
      throw const ApiKeyFailure('OpenRouter API Key is missing. Please set it in Settings.');
    }

    final targetModel = (model == null || model.trim().isEmpty)
        ? AppConstants.defaultOpenRouterModel
        : model.trim();

    final baseUrl = (customBaseUrl != null && customBaseUrl.trim().isNotEmpty)
        ? customBaseUrl.trim()
        : ApiEndpoints.defaultOpenRouterBaseUrl;

    final normalizedBaseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final endpoint = '$normalizedBaseUrl/chat/completions';

    final List<Map<String, String>> messages = [];
    if (systemPrompt.trim().isNotEmpty) {
      messages.add({'role': 'system', 'content': systemPrompt.trim()});
    }

    for (final msg in history) {
      final text = msg.content.trim();
      if (text.isEmpty || msg.isError || msg.isStreaming) continue;
      final role = msg.isUser ? 'user' : 'assistant';

      if (messages.isNotEmpty && messages.last['role'] == role) {
        messages.last['content'] = '${messages.last['content']}\n\n$text';
      } else {
        messages.add({'role': role, 'content': text});
      }
    }

    if (messages.isEmpty || (messages.length == 1 && messages.first['role'] == 'system')) {
      messages.add({'role': 'user', 'content': 'Hello'});
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
            'Authorization': 'Bearer $cleanKey',
            'HTTP-Referer': 'https://polyvoice.ai',
            'X-Title': 'PolyVoice AI',
            'Content-Type': 'application/json',
          },
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 35),
        ),
      );
    } on DioException catch (e) {
      final errorDetail = await _extractDioErrorDetail(e);
      final statusCode = e.response?.statusCode;

      if (statusCode == 401) {
        throw ApiKeyFailure('Invalid OpenRouter / OpenAI Key: $errorDetail', statusCode: statusCode);
      } else if (statusCode == 402) {
        throw ApiKeyFailure('OpenRouter Insufficient Credits (402): $errorDetail', statusCode: statusCode);
      } else if (statusCode == 429) {
        throw RateLimitFailure('OpenRouter rate limit reached: $errorDetail', statusCode: statusCode);
      } else if (statusCode == 400) {
        throw ApiKeyFailure('OpenRouter Bad Request (400): $errorDetail', statusCode: statusCode);
      } else if (statusCode == 404) {
        throw NetworkFailure('Model "$targetModel" not found on OpenRouter (404): $errorDetail', statusCode: statusCode);
      } else if (e.type == DioExceptionType.connectionTimeout ||
                 e.type == DioExceptionType.sendTimeout ||
                 e.type == DioExceptionType.receiveTimeout) {
        throw const NetworkFailure('Connection timed out while connecting to OpenRouter. Please check your network.');
      } else if (e.type == DioExceptionType.connectionError) {
        throw const NetworkFailure('Cannot connect to OpenRouter. Please check your internet connection.');
      }
      throw NetworkFailure('Network error connecting to OpenRouter: $errorDetail', statusCode: statusCode);
    } catch (e) {
      throw NetworkFailure('Unexpected error connecting to OpenRouter: $e');
    }

    final stream = response.data?.stream;
    if (stream == null) {
      throw const NetworkFailure('Empty response stream received from OpenRouter API.');
    }

    final lineStream = stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    bool receivedAny = false;
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
              receivedAny = true;
              yield content;
            }
          }
        } catch (_) {
          // Ignore partial or unparseable SSE chunks
        }
      }
    }

    if (!receivedAny) {
      yield '';
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
            'Authorization': 'Bearer ${apiKey.trim()}',
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

  Future<String> _extractDioErrorDetail(DioException e) async {
    if (e.response?.data is ResponseBody) {
      try {
        final responseBody = e.response!.data as ResponseBody;
        final builder = BytesBuilder(copy: false);
        await for (final chunk in responseBody.stream) {
          builder.add(chunk);
        }
        final bytes = builder.takeBytes();
        final text = utf8.decode(bytes);
        if (text.isNotEmpty) {
          try {
            final decoded = jsonDecode(text);
            if (decoded is Map<String, dynamic>) {
              if (decoded['error'] is Map) {
                return decoded['error']['message']?.toString() ?? text;
              } else if (decoded['error'] is String) {
                return decoded['error'];
              }
            }
          } catch (_) {
            return text;
          }
        }
      } catch (_) {}
    }
    return e.message ?? e.toString();
  }
}
