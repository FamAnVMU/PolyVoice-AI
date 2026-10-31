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

class OpenAiService implements LlmProvider {
  final Dio _dio;

  OpenAiService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 20),
                sendTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 60),
              ),
            );

  @override
  String get providerName => AppConstants.providerOpenAi;

  @override
  Stream<String> streamChat({
    required List<ChatMessage> history,
    required String systemPrompt,
    required String apiKey,
    String? model,
    String? customBaseUrl,
    CancelToken? cancelToken,
  }) async* {
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) {
      throw const ApiKeyFailure('OpenAI API Key chưa được cài đặt. Vui lòng nhập trong Cài đặt.');
    }

    final targetModel = (model == null || model.trim().isEmpty)
        ? AppConstants.defaultOpenAiModel
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

    final endpoint = ApiEndpoints.openAiChatCompletions;
    final isReasoningModel = targetModel.startsWith('o1') || targetModel.startsWith('o3');

    final Map<String, dynamic> body = {
      'model': targetModel,
      'messages': messages,
      'stream': true,
    };

    if (isReasoningModel) {
      body['max_completion_tokens'] = 4096;
    } else {
      body['temperature'] = 0.7;
      body['max_tokens'] = 4096;
    }

    final stopwatch = Stopwatch()..start();
    NetworkLogger.logRequest(service: 'OpenAI', endpoint: endpoint);

    ResponseBody responseBody;
    try {
      final response = await _dio.post<ResponseBody>(
        endpoint,
        data: jsonEncode(body),
        cancelToken: cancelToken,
        options: Options(
          headers: {
            'Authorization': 'Bearer $cleanKey',
            'Content-Type': 'application/json',
          },
          responseType: ResponseType.stream,
        ),
      );

      responseBody = response.data!;
    } on DioException catch (e) {
      stopwatch.stop();
      final detail = await _extractDioErrorDetail(e);
      NetworkLogger.logError(
        service: 'OpenAI',
        endpoint: endpoint,
        statusCode: e.response?.statusCode ?? 500,
        durationMs: stopwatch.elapsedMilliseconds,
        error: detail,
      );

      if (e.response?.statusCode == 401) {
        throw ApiKeyFailure('Khóa OpenAI API Key không hợp lệ hoặc đã bị vô hiệu hóa ($detail)', statusCode: 401);
      } else if (e.response?.statusCode == 429) {
        throw ApiKeyFailure('Tài khoản OpenAI đã hết hạn mức sử dụng (Quota) hoặc bị giới hạn tần suất: $detail', statusCode: 429);
      } else if (e.response?.statusCode == 404) {
        throw NetworkFailure('Mô hình OpenAI "$targetModel" không tồn tại hoặc tài khoản của bạn chưa được cấp quyền truy cập.', statusCode: 404);
      }
      throw NetworkFailure('Lỗi kết nối OpenAI: $detail', statusCode: e.response?.statusCode);
    }

    final Stream<String> lineStream = responseBody.stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    bool receivedAnyToken = false;

    await for (final line in lineStream) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed == 'data: [DONE]') break;

      if (trimmed.startsWith('data:')) {
        final payload = trimmed.substring(5).trim();
        if (payload.isEmpty || payload == '[DONE]') break;

        try {
          final jsonMap = jsonDecode(payload) as Map<String, dynamic>;
          final choices = jsonMap['choices'] as List<dynamic>?;
          if (choices != null && choices.isNotEmpty) {
            final firstChoice = choices[0] as Map<String, dynamic>;
            final delta = firstChoice['delta'] as Map<String, dynamic>?;
            final content = delta?['content'] as String?;
            if (content != null && content.isNotEmpty) {
              receivedAnyToken = true;
              yield content;
            }
          }
        } catch (_) {}
      }
    }

    if (!receivedAnyToken) {
      yield 'Không nhận được dữ liệu từ OpenAI. Vui lòng kiểm tra lại cấu hình mô hình.';
    }
  }

  @override
  Future<bool> testConnection({
    required String apiKey,
    String? model,
    String? customBaseUrl,
  }) async {
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) {
      throw const ApiKeyFailure('Vui lòng nhập OpenAI API Key trước khi kiểm tra.');
    }

    try {
      final response = await _dio.get(
        ApiEndpoints.openAiModels,
        options: Options(
          headers: {'Authorization': 'Bearer $cleanKey'},
          sendTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 12),
        ),
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      final detail = await _extractDioErrorDetail(e);
      if (e.response?.statusCode == 401) {
        throw ApiKeyFailure('Khóa OpenAI API Key không hợp lệ (401 Unauthorized): $detail', statusCode: 401);
      } else if (e.response?.statusCode == 429) {
        throw ApiKeyFailure('Tài khoản OpenAI đã hết hạn mức tín dụng hoặc bị giới hạn tần suất (429): $detail', statusCode: 429);
      }
      throw NetworkFailure('Lỗi kiểm tra OpenAI: $detail', statusCode: e.response?.statusCode);
    } catch (e) {
      throw NetworkFailure('Lỗi kết nối OpenAI: $e');
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
          final decoded = jsonDecode(text);
          if (decoded is Map && decoded['error'] is Map) {
            return decoded['error']['message']?.toString() ?? text;
          }
          return text;
        }
      } catch (_) {}
    } else if (e.response?.data is Map) {
      final map = e.response!.data as Map;
      if (map['error'] is Map) {
        return map['error']['message']?.toString() ?? map.toString();
      }
      return map.toString();
    } else if (e.response?.data is String) {
      return e.response!.data as String;
    }
    return e.message ?? e.toString();
  }
}
