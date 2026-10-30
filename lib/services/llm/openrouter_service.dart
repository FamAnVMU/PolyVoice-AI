import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/failures.dart';
import '../../core/network/network_logger.dart';
import '../../features/chat/data/models/chat_message.dart';
import 'llm_provider.dart';

class OpenRouterService implements LlmProvider {
  final Dio _dio;

  OpenRouterService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 20),
                sendTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 60),
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
      throw const ApiKeyFailure('OpenRouter / OpenAI-Compatible API Key is missing. Please set it in Settings.');
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

    final stopwatch = Stopwatch()..start();
    NetworkLogger.logRequest(service: 'OpenRouter', endpoint: endpoint);

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
          sendTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

      NetworkLogger.logResponse(
        service: 'OpenRouter',
        endpoint: endpoint,
        statusCode: response.statusCode ?? 200,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } on DioException catch (e) {
      final errorDetail = await _extractDioErrorDetail(e);
      final statusCode = e.response?.statusCode;

      NetworkLogger.logError(
        service: 'OpenRouter',
        endpoint: endpoint,
        error: errorDetail,
        statusCode: statusCode,
        durationMs: stopwatch.elapsedMilliseconds,
      );

      final userFriendlyMsg = NetworkLogger.formatUserMessage(
        errorDetail,
        service: 'OpenRouter',
        model: targetModel,
        statusCode: statusCode,
      );

      if (statusCode == 401) {
        throw ApiKeyFailure(userFriendlyMsg, statusCode: statusCode);
      } else if (statusCode == 402) {
        throw ApiKeyFailure('Tài khoản OpenRouter của bạn đã hết số dư (Credits). Vui lòng nạp thêm tín dụng.', statusCode: statusCode);
      } else if (statusCode == 429) {
        throw RateLimitFailure(userFriendlyMsg, statusCode: statusCode);
      } else if (statusCode == 400) {
        throw ApiKeyFailure(userFriendlyMsg, statusCode: statusCode);
      } else if (statusCode == 404) {
        throw NetworkFailure(userFriendlyMsg, statusCode: statusCode);
      } else if (e.type == DioExceptionType.connectionTimeout ||
                 e.type == DioExceptionType.sendTimeout ||
                 e.type == DioExceptionType.receiveTimeout) {
        throw NetworkFailure('Hết thời gian chờ phản hồi từ OpenRouter (Timeout). Vui lòng thử lại.', statusCode: statusCode);
      } else if (e.type == DioExceptionType.connectionError) {
        throw NetworkFailure('Không thể kết nối đến máy chủ OpenRouter. Vui lòng kiểm tra Internet.', statusCode: statusCode);
      }
      throw NetworkFailure(userFriendlyMsg, statusCode: statusCode);
    } catch (e) {
      NetworkLogger.logError(
        service: 'OpenRouter',
        endpoint: endpoint,
        error: e,
        durationMs: stopwatch.elapsedMilliseconds,
      );
      throw NetworkFailure('Lỗi không xác định khi kết nối OpenRouter: $e');
    }

    final stream = response.data?.stream;
    if (stream == null) {
      throw const NetworkFailure('Dữ liệu luồng trả về từ OpenRouter rỗng.');
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

          if (jsonMap['error'] != null) {
            final errObj = jsonMap['error'];
            final errMsg = errObj is Map ? (errObj['message']?.toString() ?? 'OpenRouter Error') : errObj.toString();
            throw NetworkFailure('Lỗi từ OpenRouter API: $errMsg');
          }

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
        } catch (e) {
          if (e is Failure) rethrow;
          // Ignore partial or unparseable SSE chunks
        }
      }
    }

    if (!receivedAny) {
      yield 'Xin lỗi, OpenRouter không trả về nội dung cho câu hỏi này. Bạn hãy thử đặt lại câu hỏi nhé.';
    }
  }

  @override
  Future<bool> testConnection({
    required String apiKey,
    String? model,
    String? customBaseUrl,
  }) async {
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) return false;

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
            'Authorization': 'Bearer $cleanKey',
            'HTTP-Referer': 'https://polyvoice.ai',
            'X-Title': 'PolyVoice AI',
          },
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      final detail = await _extractDioErrorDetail(e);
      if (e.response?.statusCode == 401) {
        throw ApiKeyFailure('Khóa OpenRouter API Key không hợp lệ: $detail', statusCode: 401);
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
    } else if (e.response?.data is Map) {
      final map = e.response!.data as Map;
      if (map['error'] is Map) {
        return map['error']['message']?.toString() ?? map.toString();
      } else if (map['error'] is String) {
        return map['error'];
      }
    } else if (e.response?.data is String) {
      final str = e.response!.data as String;
      try {
        final decoded = jsonDecode(str);
        if (decoded is Map && decoded['error'] is Map) {
          return decoded['error']['message']?.toString() ?? str;
        }
      } catch (_) {}
      return str;
    }
    return e.message ?? e.toString();
  }
}
