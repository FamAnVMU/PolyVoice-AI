import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/failures.dart';
import '../../features/chat/data/models/chat_message.dart';
import 'llm_provider.dart';

class GeminiService implements LlmProvider {
  final Dio _dio;

  GeminiService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                sendTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 35),
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
          {'text': 'Hello'}
        ],
      });
    } else if (contents.last['role'] != 'user') {
      contents.add({
        'role': 'user',
        'parts': [
          {'text': 'Please continue.'}
        ],
      });
    }

    final Map<String, dynamic> body = {
      if (systemPrompt.trim().isNotEmpty)
        'systemInstruction': {
          'parts': [
            {'text': systemPrompt.trim()}
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
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 35),
        ),
      );
    } on DioException catch (e) {
      final errorDetail = await _extractDioErrorDetail(e);
      final statusCode = e.response?.statusCode;

      if (statusCode == 400 || statusCode == 403) {
        if (errorDetail.toLowerCase().contains('api key') ||
            errorDetail.toLowerCase().contains('unauthorized') ||
            statusCode == 403) {
          throw ApiKeyFailure('Invalid or unauthorized Gemini API Key: $errorDetail', statusCode: statusCode);
        }
        throw ApiKeyFailure('Gemini Bad Request ($statusCode): $errorDetail', statusCode: statusCode);
      } else if (statusCode == 429) {
        throw RateLimitFailure('Gemini API rate limit reached: $errorDetail', statusCode: statusCode);
      } else if (statusCode == 404) {
        throw NetworkFailure('Model "$targetModel" not found (404). Please verify model name: $errorDetail', statusCode: statusCode);
      } else if (e.type == DioExceptionType.connectionTimeout ||
                 e.type == DioExceptionType.sendTimeout ||
                 e.type == DioExceptionType.receiveTimeout) {
        throw const NetworkFailure('Connection timed out while connecting to Gemini. Please check your network.');
      } else if (e.type == DioExceptionType.connectionError) {
        throw const NetworkFailure('Cannot connect to Gemini servers. Please check your internet connection.');
      }
      throw NetworkFailure('Network error connecting to Gemini: $errorDetail', statusCode: statusCode);
    } catch (e) {
      throw NetworkFailure('Unexpected error connecting to Gemini: $e');
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

    bool receivedAnyToken = false;
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
                receivedAnyToken = true;
                yield text;
              }
            }
          }
        } catch (_) {
          // Skip malformed SSE chunks
        }
      }
    }

    if (!receivedAnyToken) {
      // Yield at least a space if Gemini returned empty candidates
      yield '';
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
        ApiEndpoints.geminiPing(apiKey.trim()),
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
