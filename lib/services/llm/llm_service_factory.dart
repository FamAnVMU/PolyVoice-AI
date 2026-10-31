import '../../core/constants/app_constants.dart';
import 'anthropic_service.dart';
import 'gemini_service.dart';
import 'groq_service.dart';
import 'llm_provider.dart';
import 'local_ai_service.dart';
import 'openai_service.dart';
import 'openrouter_service.dart';

class LlmServiceFactory {
  final GeminiService geminiService;
  final OpenAiService openAiService;
  final AnthropicService anthropicService;
  final GroqService groqService;
  final OpenRouterService openRouterService;
  final LocalAiService localAiService;

  LlmServiceFactory({
    GeminiService? gemini,
    OpenAiService? openAi,
    AnthropicService? anthropic,
    GroqService? groq,
    OpenRouterService? openRouter,
    LocalAiService? localAi,
  })  : geminiService = gemini ?? GeminiService(),
        openAiService = openAi ?? OpenAiService(),
        anthropicService = anthropic ?? AnthropicService(),
        groqService = groq ?? GroqService(),
        openRouterService = openRouter ?? OpenRouterService(),
        localAiService = localAi ?? LocalAiService();

  LlmProvider getProvider(String providerName) {
    switch (providerName) {
      case AppConstants.providerOpenAi:
        return openAiService;
      case AppConstants.providerAnthropic:
        return anthropicService;
      case AppConstants.providerGroq:
        return groqService;
      case AppConstants.providerOpenRouter:
        return openRouterService;
      case AppConstants.providerLocal:
        return localAiService;
      case AppConstants.providerGemini:
      default:
        return geminiService;
    }
  }
}
