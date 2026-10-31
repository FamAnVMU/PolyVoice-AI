class ApiEndpoints {
  // Google Gemini API
  static const String geminiBaseUrl = 'https://generativelanguage.googleapis.com/v1beta';
  static String geminiStream(String model, String apiKey) =>
      '$geminiBaseUrl/models/$model:streamGenerateContent?alt=sse&key=$apiKey';
  static String geminiPing(String apiKey) =>
      '$geminiBaseUrl/models?key=$apiKey';

  // OpenAI API
  static const String openAiBaseUrl = 'https://api.openai.com/v1';
  static const String openAiChatCompletions = '$openAiBaseUrl/chat/completions';
  static const String openAiModels = '$openAiBaseUrl/models';

  // Anthropic Claude API
  static const String anthropicBaseUrl = 'https://api.anthropic.com/v1';
  static const String anthropicMessages = '$anthropicBaseUrl/messages';

  // Groq Cloud API (OpenAI compatible)
  static const String groqBaseUrl = 'https://api.groq.com/openai/v1';
  static const String groqChatCompletions = '$groqBaseUrl/chat/completions';
  static const String groqAudioTranscriptions = '$groqBaseUrl/audio/transcriptions';
  static const String groqModels = '$groqBaseUrl/models';

  // OpenRouter / Custom OpenAI-compatible Base
  static const String defaultOpenRouterBaseUrl = 'https://openrouter.ai/api/v1';
  static const String openRouterChatCompletions = '$defaultOpenRouterBaseUrl/chat/completions';
  static const String openRouterModels = '$defaultOpenRouterBaseUrl/models';

  // Local AI (Ollama / LocalAI / LM Studio on Device or LAN)
  static const String defaultLocalAiBaseUrl = 'http://127.0.0.1:11434';
  static const String defaultLocalAiChat = '$defaultLocalAiBaseUrl/api/chat';
  static const String defaultLocalAiTags = '$defaultLocalAiBaseUrl/api/tags';
  static const String defaultLocalAiOpenAiCompletions = '$defaultLocalAiBaseUrl/v1/chat/completions';
  static const String defaultLocalAiOpenAiModels = '$defaultLocalAiBaseUrl/v1/models';
}
