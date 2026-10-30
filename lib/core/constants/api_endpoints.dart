class ApiEndpoints {
  // Google Gemini API
  static const String geminiBaseUrl = 'https://generativelanguage.googleapis.com/v1beta';
  static String geminiStream(String model, String apiKey) =>
      '$geminiBaseUrl/models/$model:streamGenerateContent?alt=sse&key=$apiKey';
  static String geminiPing(String apiKey) =>
      '$geminiBaseUrl/models?key=$apiKey';

  // Groq Cloud API (OpenAI compatible)
  static const String groqBaseUrl = 'https://api.groq.com/openai/v1';
  static const String groqChatCompletions = '$groqBaseUrl/chat/completions';
  static const String groqAudioTranscriptions = '$groqBaseUrl/audio/transcriptions';
  static const String groqModels = '$groqBaseUrl/models';

  // OpenRouter / Custom OpenAI-compatible Base
  static const String defaultOpenRouterBaseUrl = 'https://openrouter.ai/api/v1';
  static const String openRouterChatCompletions = '$defaultOpenRouterBaseUrl/chat/completions';
  static const String openRouterModels = '$defaultOpenRouterBaseUrl/models';
}
