import '../../core/constants/app_constants.dart';
import 'gemini_service.dart';
import 'groq_service.dart';
import 'llm_provider.dart';
import 'openrouter_service.dart';

class LlmServiceFactory {
  final GeminiService geminiService;
  final GroqService groqService;
  final OpenRouterService openRouterService;

  LlmServiceFactory({
    GeminiService? gemini,
    GroqService? groq,
    OpenRouterService? openRouter,
  })  : geminiService = gemini ?? GeminiService(),
        groqService = groq ?? GroqService(),
        openRouterService = openRouter ?? OpenRouterService();

  LlmProvider getProvider(String providerName) {
    switch (providerName) {
      case AppConstants.providerGroq:
        return groqService;
      case AppConstants.providerOpenRouter:
        return openRouterService;
      case AppConstants.providerGemini:
      default:
        return geminiService;
    }
  }
}
