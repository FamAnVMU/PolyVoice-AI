import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/failures.dart';
import '../../core/network/network_logger.dart';
import '../../features/chat/data/models/chat_message.dart';
import 'llm_provider.dart';

class LocalAiService implements LlmProvider {
  final Dio _dio;

  LocalAiService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                sendTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 120),
              ),
            );

  @override
  String get providerName => AppConstants.providerLocal;

  @override
  Stream<String> streamChat({
    required List<ChatMessage> history,
    required String systemPrompt,
    required String apiKey,
    String? model,
    String? customBaseUrl,
    CancelToken? cancelToken,
  }) async* {
    final effectiveBaseUrl = (customBaseUrl == null || customBaseUrl.trim().isEmpty)
        ? ApiEndpoints.defaultLocalAiBaseUrl
        : customBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');

    final targetModel = (model == null || model.trim().isEmpty)
        ? AppConstants.defaultLocalModel
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

    if (messages.isEmpty || messages.last['role'] != 'user') {
      messages.add({'role': 'user', 'content': 'Xin chào'});
    }

    // Try OpenAI-compatible endpoint first (/v1/chat/completions), fallback to Ollama (/api/chat)
    final isOpenAiFormat = effectiveBaseUrl.endsWith('/v1');
    final endpoint = isOpenAiFormat
        ? '$effectiveBaseUrl/chat/completions'
        : '$effectiveBaseUrl/api/chat';

    final Map<String, dynamic> body = isOpenAiFormat
        ? {
            'model': targetModel,
            'messages': messages,
            'stream': true,
            'temperature': 0.7,
          }
        : {
            'model': targetModel,
            'messages': messages,
            'stream': true,
          };

    final stopwatch = Stopwatch()..start();
    NetworkLogger.logRequest(service: 'Local AI', endpoint: endpoint);

    ResponseBody responseBody;
    try {
      final response = await _dio.post<ResponseBody>(
        endpoint,
        data: jsonEncode(body),
        cancelToken: cancelToken,
        options: Options(
          headers: {'Content-Type': 'application/json'},
          responseType: ResponseType.stream,
        ),
      );

      responseBody = response.data!;
    } on DioException catch (e) {
      stopwatch.stop();
      NetworkLogger.logError(
        service: 'Local AI',
        endpoint: endpoint,
        statusCode: e.response?.statusCode ?? 500,
        durationMs: stopwatch.elapsedMilliseconds,
        error: e.message,
      );

      if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
        throw NetworkFailure(
          'Không thể kết nối đến máy chủ AI Local tại $effectiveBaseUrl. '
          'Vui lòng đảm bảo Ollama hoặc daemon Local AI đang chạy trên máy/mạng nội bộ.',
        );
      }
      throw NetworkFailure('Lỗi thực thi Local AI: ${e.message}');
    }

    final Stream<String> lineStream = responseBody.stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    bool receivedAnyToken = false;

    await for (final line in lineStream) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (isOpenAiFormat) {
        // SSE Format (data: {...})
        if (trimmed == 'data: [DONE]') break;
        if (trimmed.startsWith('data:')) {
          final payload = trimmed.substring(5).trim();
          if (payload.isEmpty || payload == '[DONE]') break;
          try {
            final jsonMap = jsonDecode(payload) as Map<String, dynamic>;
            final choices = jsonMap['choices'] as List<dynamic>?;
            if (choices != null && choices.isNotEmpty) {
              final first = choices[0] as Map<String, dynamic>;
              final delta = first['delta'] as Map<String, dynamic>?;
              final content = delta?['content'] as String?;
              if (content != null && content.isNotEmpty) {
                receivedAnyToken = true;
                yield content;
              }
            }
          } catch (_) {}
        }
      } else {
        // Ollama ndjson Format ({"message": {"content": "..."}, "done": false})
        try {
          final jsonMap = jsonDecode(trimmed) as Map<String, dynamic>;
          final msgMap = jsonMap['message'] as Map<String, dynamic>?;
          final content = msgMap?['content'] as String?;
          if (content != null && content.isNotEmpty) {
            receivedAnyToken = true;
            yield content;
          }
          if (jsonMap['done'] == true) break;
        } catch (_) {}
      }
    }

    if (!receivedAnyToken) {
      yield 'Mô hình Local AI không trả về dữ liệu. Vui lòng kiểm tra lại trạng thái model trên thiết bị.';
    }
  }

  @override
  Future<bool> testConnection({
    required String apiKey,
    String? model,
    String? customBaseUrl,
  }) async {
    final effectiveBaseUrl = (customBaseUrl == null || customBaseUrl.trim().isEmpty)
        ? ApiEndpoints.defaultLocalAiBaseUrl
        : customBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');

    try {
      // 1. Try Ollama tags endpoint
      final testUrl = effectiveBaseUrl.endsWith('/v1')
          ? '$effectiveBaseUrl/models'
          : '$effectiveBaseUrl/api/tags';

      final response = await _dio.get(
        testUrl,
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

      return response.statusCode == 200;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
        throw NetworkFailure(
          'Không thể kết nối đến Local AI tại $effectiveBaseUrl. '
          'Hãy chắc chắn rằng ứng dụng Ollama hoặc máy chủ AI cục bộ của bạn đã được khởi động.',
        );
      }
      throw NetworkFailure('Lỗi kiểm tra Local AI: ${e.message}');
    } catch (e) {
      throw NetworkFailure('Lỗi kết nối Local AI: $e');
    }
  }
}
