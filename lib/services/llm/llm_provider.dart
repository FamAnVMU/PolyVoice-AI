import 'package:dio/dio.dart';
import '../../features/chat/data/models/chat_message.dart';

abstract class LlmProvider {
  String get providerName;

  /// Streams generated text tokens from the LLM provider with optional cancellation support.
  Stream<String> streamChat({
    required List<ChatMessage> history,
    required String systemPrompt,
    required String apiKey,
    String? model,
    String? customBaseUrl,
    CancelToken? cancelToken,
  });

  /// Tests the validity of the provided API key with a fast ping request.
  Future<bool> testConnection({
    required String apiKey,
    String? model,
    String? customBaseUrl,
  });
}
