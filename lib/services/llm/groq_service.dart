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

class GroqService implements LlmProvider {
  final Dio _dio;

  GroqService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 20),
                sendTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 60),
              ),
            );

  @override
  String get providerName => AppConstants.providerGroq;

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
      throw const ApiKeyFailure('Groq Cloud API Key is missing. Please set it in Settings.');
    }

    final targetModel = (model == null || model.trim().isEmpty)
        ? AppConstants.defaultGroqModel
        : model.trim();

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
      'max_tokens': 8192,
    };

    final stopwatch = Stopwatch()..start();
    NetworkLogger.logRequest(service: 'Groq', endpoint: ApiEndpoints.groqChatCompletions);

    Response<ResponseBody> response;
    try {
      response = await _dio.post<ResponseBody>(
        ApiEndpoints.groqChatCompletions,
        data: body,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'Authorization': 'Bearer $cleanKey',
            'Content-Type': 'application/json',
          },
          sendTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

      NetworkLogger.logResponse(
        service: 'Groq',
        endpoint: ApiEndpoints.groqChatCompletions,
        statusCode: response.statusCode ?? 200,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } on DioException catch (e) {
      final errorDetail = await _extractDioErrorDetail(e);
      final statusCode = e.response?.statusCode;

      NetworkLogger.logError(
        service: 'Groq',
        endpoint: ApiEndpoints.groqChatCompletions,
        error: errorDetail,
        statusCode: statusCode,
        durationMs: stopwatch.elapsedMilliseconds,
      );

      final userFriendlyMsg = NetworkLogger.formatUserMessage(
        errorDetail,
        service: 'Groq Cloud',
        model: targetModel,
        statusCode: statusCode,
      );

      if (statusCode == 401) {
        throw ApiKeyFailure(userFriendlyMsg, statusCode: statusCode);
      } else if (statusCode == 429) {
        throw RateLimitFailure(userFriendlyMsg, statusCode: statusCode);
      } else if (statusCode == 400) {
        throw ApiKeyFailure(userFriendlyMsg, statusCode: statusCode);
      } else if (statusCode == 404) {
        throw NetworkFailure(userFriendlyMsg, statusCode: statusCode);
      } else if (e.type == DioExceptionType.connectionTimeout ||
                 e.type == DioExceptionType.sendTimeout ||
                 e.type == DioExceptionType.receiveTimeout) {
        throw NetworkFailure('Hết thời gian chờ phản hồi từ Groq (Timeout). Vui lòng thử lại.', statusCode: statusCode);
      } else if (e.type == DioExceptionType.connectionError) {
        throw NetworkFailure('Không thể kết nối đến máy chủ Groq. Vui lòng kiểm tra Internet.', statusCode: statusCode);
      }
      throw NetworkFailure(userFriendlyMsg, statusCode: statusCode);
    } catch (e) {
      NetworkLogger.logError(
        service: 'Groq',
        endpoint: ApiEndpoints.groqChatCompletions,
        error: e,
        durationMs: stopwatch.elapsedMilliseconds,
      );
      throw NetworkFailure('Lỗi không xác định khi kết nối Groq: $e');
    }

    final stream = response.data?.stream;
    if (stream == null) {
      throw const NetworkFailure('Dữ liệu luồng trả về từ Groq rỗng.');
    }

    final lineStream = stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    Stream<String> parseJsonChunk(Map<String, dynamic> jsonMap) async* {
      if (jsonMap['error'] != null) {
        final errObj = jsonMap['error'];
        final errMsg = errObj is Map ? (errObj['message']?.toString() ?? 'Groq Error') : errObj.toString();
        throw NetworkFailure('Lỗi từ Groq API: $errMsg');
      }

      final choices = jsonMap['choices'] as List<dynamic>?;
      if (choices != null && choices.isNotEmpty) {
        for (final choice in choices) {
          if (choice is Map<String, dynamic>) {
            final finishReason = choice['finish_reason'] as String?;
            if (finishReason == 'length') {
              yield '\n\n*(Lưu ý: Phản hồi đã đạt giới hạn độ dài tối đa của mô hình)*';
              break;
            }

            final delta = choice['delta'] as Map<String, dynamic>?;
            // Ignore internal reasoning tags & reasoning_content
            final content = delta?['content'] as String?;
            if (content != null && content.isNotEmpty) {
              yield content;
            }
          }
        }
      }
    }

    final StringBuffer eventBuffer = StringBuffer();
    bool receivedAny = false;

    await for (final line in lineStream) {
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        if (eventBuffer.isNotEmpty) {
          final payload = eventBuffer.toString().trim();
          eventBuffer.clear();
          if (payload == '[DONE]') break;
          try {
            final jsonMap = jsonDecode(payload) as Map<String, dynamic>;
            await for (final token in parseJsonChunk(jsonMap)) {
              receivedAny = true;
              yield token;
            }
          } catch (_) {}
        }
        continue;
      }

      if (trimmed.startsWith('data:')) {
        final payload = trimmed.substring(5).trim();
        if (payload == '[DONE]') break;

        bool parsedDirectly = false;
        if (payload.startsWith('{') && payload.endsWith('}')) {
          try {
            final jsonMap = jsonDecode(payload) as Map<String, dynamic>;
            parsedDirectly = true;
            eventBuffer.clear();
            await for (final token in parseJsonChunk(jsonMap)) {
              receivedAny = true;
              yield token;
            }
          } catch (_) {
            parsedDirectly = false;
          }
        }

        if (!parsedDirectly) {
          if (eventBuffer.isNotEmpty) {
            eventBuffer.write('\n');
          }
          eventBuffer.write(payload);
        }
      }
    }

    if (eventBuffer.isNotEmpty) {
      final payload = eventBuffer.toString().trim();
      if (payload != '[DONE]') {
        try {
          final jsonMap = jsonDecode(payload) as Map<String, dynamic>;
          await for (final token in parseJsonChunk(jsonMap)) {
            receivedAny = true;
            yield token;
          }
        } catch (_) {}
      }
    }

    if (!receivedAny) {
      yield 'Xin lỗi, Groq không trả về nội dung cho câu hỏi này. Bạn hãy thử đặt lại câu hỏi nhé.';
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

    try {
      final response = await _dio.get(
        ApiEndpoints.groqModels,
        options: Options(
          headers: {'Authorization': 'Bearer $cleanKey'},
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      final detail = await _extractDioErrorDetail(e);
      if (e.response?.statusCode == 401) {
        throw ApiKeyFailure('Khóa Groq API Key không hợp lệ: $detail', statusCode: 401);
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
