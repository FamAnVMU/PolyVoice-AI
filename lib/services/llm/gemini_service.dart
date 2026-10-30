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

class GeminiService implements LlmProvider {
  final Dio _dio;

  GeminiService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 20),
                sendTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 60),
              ),
            );

  @override
  String get providerName => AppConstants.providerGemini;

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
      throw const ApiKeyFailure('Google Gemini API Key is missing. Please set it in Settings.');
    }

    String targetModel = (model == null || model.trim().isEmpty)
        ? AppConstants.defaultGeminiModel
        : model.trim();
    if (targetModel.startsWith('models/')) {
      targetModel = targetModel.substring(7);
    }

    final url = ApiEndpoints.geminiStream(targetModel, cleanKey);
    final stopwatch = Stopwatch()..start();
    NetworkLogger.logRequest(service: 'Gemini', endpoint: url);

    // Format & sanitize Gemini history payload with strict turn alternation:
    // Gemini requires strict (user -> model -> user -> ...) alternation, starting and ending with user.
    final List<Map<String, dynamic>> contents = [];
    String? currentRole;
    final List<String> currentParts = [];

    void flushTurn() {
      if (currentRole != null && currentParts.isNotEmpty) {
        final combinedText = currentParts.join('\n\n').trim();
        if (combinedText.isNotEmpty) {
          contents.add({
            'role': currentRole == 'user' ? 'user' : 'model',
            'parts': [
              {'text': combinedText}
            ],
          });
        }
      }
      currentRole = null;
      currentParts.clear();
    }

    for (final msg in history) {
      final text = msg.content.trim();
      if (text.isEmpty || msg.isError || msg.isStreaming) continue;
      final role = msg.isUser ? 'user' : 'model';

      if (currentRole == role) {
        currentParts.add(text);
      } else {
        flushTurn();
        currentRole = role;
        currentParts.add(text);
      }
    }
    flushTurn();

    // Ensure Gemini contents start with a 'user' turn
    while (contents.isNotEmpty && contents.first['role'] != 'user') {
      contents.removeAt(0);
    }

    // Ensure contents are not empty and end with 'user'
    if (contents.isEmpty) {
      contents.add({
        'role': 'user',
        'parts': [
          {'text': 'Xin chào'}
        ],
      });
    } else if (contents.last['role'] != 'user') {
      contents.add({
        'role': 'user',
        'parts': [
          {'text': 'Hãy tiếp tục câu trả lời của bạn.'}
        ],
      });
    }

    // Configure generation settings based on Gemini version:
    // Gemini 3.x models (e.g. gemini-3.8-flash) no longer support 'temperature', 'topP', 'topK'.
    final isGemini3 = targetModel.contains('gemini-3') || targetModel.contains('3.');
    final Map<String, dynamic> generationConfig = {
      'maxOutputTokens': 8192,
    };
    if (!isGemini3) {
      generationConfig['temperature'] = 0.7;
    }

    final Map<String, dynamic> body = {
      if (systemPrompt.trim().isNotEmpty)
        'systemInstruction': {
          'parts': [
            {'text': systemPrompt.trim()}
          ],
        },
      'contents': contents,
      'generationConfig': generationConfig,
    };

    Response<ResponseBody> response;
    try {
      response = await _dio.post<ResponseBody>(
        url,
        data: body,
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': cleanKey,
          },
          sendTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

      NetworkLogger.logResponse(
        service: 'Gemini',
        endpoint: url,
        statusCode: response.statusCode ?? 200,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        return; // Barge-in cancellation
      }
      final errorDetail = await _extractDioErrorDetail(e);
      final statusCode = e.response?.statusCode;

      NetworkLogger.logError(
        service: 'Gemini',
        endpoint: url,
        error: errorDetail,
        statusCode: statusCode,
        durationMs: stopwatch.elapsedMilliseconds,
      );

      final userFriendlyMsg = NetworkLogger.formatUserMessage(
        errorDetail,
        service: 'Google Gemini',
        model: targetModel,
        statusCode: statusCode,
      );

      if (statusCode == 400 || statusCode == 403) {
        throw ApiKeyFailure(userFriendlyMsg, statusCode: statusCode);
      } else if (statusCode == 429) {
        throw RateLimitFailure(userFriendlyMsg, statusCode: statusCode);
      } else if (statusCode == 404) {
        throw NetworkFailure(userFriendlyMsg, statusCode: statusCode);
      } else if (e.type == DioExceptionType.connectionTimeout ||
                 e.type == DioExceptionType.sendTimeout ||
                 e.type == DioExceptionType.receiveTimeout) {
        throw NetworkFailure('Hết thời gian chờ phản hồi từ Google Gemini (Timeout). Vui lòng thử lại.', statusCode: statusCode);
      } else if (e.type == DioExceptionType.connectionError) {
        throw NetworkFailure('Không thể kết nối đến máy chủ Google Gemini. Vui lòng kiểm tra Internet.', statusCode: statusCode);
      }
      throw NetworkFailure(userFriendlyMsg, statusCode: statusCode);
    } catch (e) {
      NetworkLogger.logError(
        service: 'Gemini',
        endpoint: url,
        error: e,
        durationMs: stopwatch.elapsedMilliseconds,
      );
      throw NetworkFailure('Lỗi không xác định khi kết nối Google Gemini: $e');
    }

    final stream = response.data?.stream;
    if (stream == null) {
      throw const NetworkFailure('Dữ liệu luồng trả về từ Google Gemini rỗng.');
    }

    // Robust SSE Stream line parser with multi-line JSON buffering & thinking filter
    final lineStream = stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    Stream<String> parseJsonChunk(Map<String, dynamic> jsonMap) async* {
      // Check for API-level error in chunk
      if (jsonMap['error'] != null) {
        final errObj = jsonMap['error'];
        final errMsg = errObj is Map ? (errObj['message']?.toString() ?? 'Gemini Error') : errObj.toString();
        throw NetworkFailure('Lỗi từ Google Gemini: $errMsg');
      }

      // Format A: New Gemini 3 / Gemini 3.8 format (content.delta / delta)
      // e.g. {"event_type": "content.delta", "delta": {"type": "text", "text": "..."}}
      if (jsonMap['delta'] is Map) {
        final delta = jsonMap['delta'] as Map<String, dynamic>;
        final deltaType = delta['type']?.toString();
        final deltaText = delta['text'] as String?;
        const ignoredTypes = ['thought', 'thought_summary', 'draft', 'reasoning', 'internal'];
        if (!ignoredTypes.contains(deltaType) && deltaText != null && deltaText.isNotEmpty) {
          yield deltaText;
        }
      }

      // Format B: Classic candidates format (Gemini 1.5, 2.0, 2.5, etc.)
      final candidates = jsonMap['candidates'] as List<dynamic>?;
      if (candidates != null && candidates.isNotEmpty) {
        for (final candidate in candidates) {
          if (candidate is Map<String, dynamic>) {
            final finishReason = candidate['finishReason'] as String?;
            if (finishReason == 'SAFETY') {
              yield '\n\n*(Lưu ý: Nội dung bị giới hạn bởi bộ lọc an toàn của Google Gemini)*';
              break;
            } else if (finishReason == 'MAX_TOKENS') {
              yield '\n\n*(Lưu ý: Phản hồi đã đạt giới hạn độ dài tối đa của mô hình)*';
              break;
            }

            final content = candidate['content'] as Map<String, dynamic>?;
            final parts = content?['parts'] as List<dynamic>?;
            if (parts != null) {
              for (final part in parts) {
                if (part is Map<String, dynamic>) {
                  final isThought = part['thought'] == true;
                  final text = part['text'] as String?;
                  if (!isThought && text != null && text.isNotEmpty) {
                    yield text;
                  }
                }
              }
            }
          }
        }
      }

      // Format C: Direct text fallback
      if (jsonMap['text'] is String && (jsonMap['text'] as String).isNotEmpty) {
        yield jsonMap['text'] as String;
      }
    }

    final StringBuffer eventBuffer = StringBuffer();
    bool receivedAnyToken = false;

    await for (final line in lineStream) {
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        // SSE event boundary
        if (eventBuffer.isNotEmpty) {
          final payload = eventBuffer.toString().trim();
          eventBuffer.clear();
          if (payload == '[DONE]') break;
          try {
            final jsonMap = jsonDecode(payload) as Map<String, dynamic>;
            await for (final token in parseJsonChunk(jsonMap)) {
              receivedAnyToken = true;
              yield token;
            }
          } catch (_) {}
        }
        continue;
      }

      if (trimmed.startsWith('data:')) {
        final payload = trimmed.substring(5).trim();
        if (payload == '[DONE]') break;

        // Fast-path: try parsing immediately if it is a complete JSON object on this line
        bool parsedDirectly = false;
        if (payload.startsWith('{') && payload.endsWith('}')) {
          try {
            final jsonMap = jsonDecode(payload) as Map<String, dynamic>;
            parsedDirectly = true;
            eventBuffer.clear();
            await for (final token in parseJsonChunk(jsonMap)) {
              receivedAnyToken = true;
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

    // Flush any leftover in eventBuffer
    if (eventBuffer.isNotEmpty) {
      final payload = eventBuffer.toString().trim();
      if (payload != '[DONE]') {
        try {
          final jsonMap = jsonDecode(payload) as Map<String, dynamic>;
          await for (final token in parseJsonChunk(jsonMap)) {
            receivedAnyToken = true;
            yield token;
          }
        } catch (_) {}
      }
    }

    if (!receivedAnyToken) {
      // Return a gentle fallback rather than crashing with NetworkFailure
      yield 'Xin lỗi, mô hình không trả về nội dung cho câu hỏi này. Bạn hãy thử đặt lại câu hỏi nhé.';
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

    String? targetModel = model?.trim();
    if (targetModel != null && targetModel.startsWith('models/')) {
      targetModel = targetModel.substring(7);
    }

    try {
      // 1. If a specific model is requested, test accessibility of that exact model
      if (targetModel != null && targetModel.isNotEmpty) {
        final specificModelUrl = '${ApiEndpoints.geminiBaseUrl}/models/$targetModel?key=$cleanKey';
        final response = await _dio.get(
          specificModelUrl,
          options: Options(
            headers: {'x-goog-api-key': cleanKey},
            sendTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        );
        if (response.statusCode == 200) {
          return true;
        }
      }

      // 2. Fallback to testing the models catalog endpoint
      final generalUrl = ApiEndpoints.geminiPing(cleanKey);
      final response = await _dio.get(
        generalUrl,
        options: Options(
          headers: {'x-goog-api-key': cleanKey},
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      final detail = await _extractDioErrorDetail(e);
      if (e.response?.statusCode == 400 || e.response?.statusCode == 403) {
        throw ApiKeyFailure('Khóa Gemini API Key không hợp lệ hoặc bị từ chối: $detail', statusCode: e.response?.statusCode);
      } else if (e.response?.statusCode == 404) {
        throw NetworkFailure('Mô hình "$targetModel" không tìm thấy trên Google API (404). Vui lòng kiểm tra lại tên Model Identifier.', statusCode: 404);
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
