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

class AnthropicService implements LlmProvider {
  final Dio _dio;

  AnthropicService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 20),
                sendTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 60),
              ),
            );

  @override
  String get providerName => AppConstants.providerAnthropic;

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
      throw const ApiKeyFailure('Anthropic Claude API Key chưa được cài đặt. Vui lòng nhập trong Cài đặt.');
    }

    final targetModel = (model == null || model.trim().isEmpty)
        ? AppConstants.defaultAnthropicModel
        : model.trim();

    final List<Map<String, String>> messages = [];
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

    // Anthropic requires strictly that messages start with a 'user' turn and cannot be empty
    while (messages.isNotEmpty && messages.first['role'] != 'user') {
      messages.removeAt(0);
    }

    if (messages.isEmpty) {
      messages.add({'role': 'user', 'content': 'Xin chào'});
    } else if (messages.last['role'] != 'user') {
      messages.add({'role': 'user', 'content': 'Tiếp tục cuộc trò chuyện.'});
    }

    final endpoint = ApiEndpoints.anthropicMessages;
    final Map<String, dynamic> body = {
      'model': targetModel,
      'messages': messages,
      'max_tokens': 4096,
      'stream': true,
    };

    if (systemPrompt.trim().isNotEmpty) {
      body['system'] = systemPrompt.trim();
    }

    final stopwatch = Stopwatch()..start();
    NetworkLogger.logRequest(service: 'Anthropic', endpoint: endpoint);

    ResponseBody responseBody;
    try {
      final response = await _dio.post<ResponseBody>(
        endpoint,
        data: jsonEncode(body),
        cancelToken: cancelToken,
        options: Options(
          headers: {
            'x-api-key': cleanKey,
            'anthropic-version': '2023-06-01',
            'content-type': 'application/json',
          },
          responseType: ResponseType.stream,
        ),
      );

      responseBody = response.data!;
    } on DioException catch (e) {
      stopwatch.stop();
      final detail = await _extractDioErrorDetail(e);
      NetworkLogger.logError(
        service: 'Anthropic',
        endpoint: endpoint,
        statusCode: e.response?.statusCode ?? 500,
        durationMs: stopwatch.elapsedMilliseconds,
        error: detail,
      );

      if (e.response?.statusCode == 401) {
        throw ApiKeyFailure('Khóa Anthropic API Key không hợp lệ ($detail)', statusCode: 401);
      } else if (e.response?.statusCode == 429) {
        throw ApiKeyFailure('Tài khoản Claude đã hết hạn mức credit hoặc bị giới hạn: $detail', statusCode: 429);
      } else if (e.response?.statusCode == 404) {
        throw NetworkFailure('Mô hình Claude "$targetModel" không tìm thấy trên hệ thống Anthropic (404).', statusCode: 404);
      }
      throw NetworkFailure('Lỗi kết nối Anthropic: $detail', statusCode: e.response?.statusCode);
    }

    final Stream<String> lineStream = responseBody.stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    bool receivedAnyToken = false;

    await for (final line in lineStream) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('data:')) {
        final payload = trimmed.substring(5).trim();
        if (payload.isEmpty || payload == '[DONE]') break;

        try {
          final jsonMap = jsonDecode(payload) as Map<String, dynamic>;
          final type = jsonMap['type'] as String?;

          if (type == 'content_block_delta') {
            final delta = jsonMap['delta'] as Map<String, dynamic>?;
            if (delta?['type'] == 'text_delta') {
              final text = delta?['text'] as String?;
              if (text != null && text.isNotEmpty) {
                receivedAnyToken = true;
                yield text;
              }
            }
          } else if (type == 'error') {
            final errorMap = jsonMap['error'] as Map<String, dynamic>?;
            final message = errorMap?['message']?.toString() ?? 'Lỗi từ Anthropic Claude';
            yield '\n\n*(Lỗi Claude: $message)*';
          }
        } catch (_) {}
      }
    }

    if (!receivedAnyToken) {
      yield 'Không nhận được dữ liệu từ Anthropic Claude. Vui lòng kiểm tra lại cấu hình.';
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
      throw const ApiKeyFailure('Vui lòng nhập Anthropic API Key trước khi kiểm tra.');
    }

    final targetModel = (model == null || model.trim().isEmpty)
        ? AppConstants.defaultAnthropicModel
        : model.trim();

    try {
      final response = await _dio.post(
        ApiEndpoints.anthropicMessages,
        data: jsonEncode({
          'model': targetModel,
          'max_tokens': 1,
          'messages': [
            {'role': 'user', 'content': 'ping'}
          ],
        }),
        options: Options(
          headers: {
            'x-api-key': cleanKey,
            'anthropic-version': '2023-06-01',
            'content-type': 'application/json',
          },
          sendTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 12),
        ),
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      final detail = await _extractDioErrorDetail(e);
      if (e.response?.statusCode == 401) {
        throw ApiKeyFailure('Khóa Anthropic API Key không hợp lệ (401 Unauthorized): $detail', statusCode: 401);
      } else if (e.response?.statusCode == 429) {
        throw ApiKeyFailure('Tài khoản Anthropic đã hết credit hoặc bị quá tải (429): $detail', statusCode: 429);
      }
      throw NetworkFailure('Lỗi kiểm tra Anthropic: $detail', statusCode: e.response?.statusCode);
    } catch (e) {
      throw NetworkFailure('Lỗi kết nối Anthropic: $e');
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
