import 'package:equatable/equatable.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_constants.dart';

class ApiKeysModel extends Equatable {
  final String geminiKey;
  final String openAiKey;
  final String anthropicKey;
  final String groqKey;
  final String openRouterKey;
  final String openRouterBaseUrl;
  final String localAiBaseUrl;
  final String localAiModel;
  final String selectedProvider;
  final String selectedModel;
  final String sttMode;

  const ApiKeysModel({
    this.geminiKey = '',
    this.openAiKey = '',
    this.anthropicKey = '',
    this.groqKey = '',
    this.openRouterKey = '',
    this.openRouterBaseUrl = ApiEndpoints.defaultOpenRouterBaseUrl,
    this.localAiBaseUrl = ApiEndpoints.defaultLocalAiBaseUrl,
    this.localAiModel = AppConstants.defaultLocalModel,
    this.selectedProvider = AppConstants.providerGemini,
    this.selectedModel = AppConstants.defaultGeminiModel,
    this.sttMode = AppConstants.sttModeOnDevice,
  });

  bool hasKeyFor(String provider) {
    switch (provider) {
      case AppConstants.providerGemini:
        return geminiKey.trim().isNotEmpty;
      case AppConstants.providerOpenAi:
        return openAiKey.trim().isNotEmpty;
      case AppConstants.providerAnthropic:
        return anthropicKey.trim().isNotEmpty;
      case AppConstants.providerGroq:
        return groqKey.trim().isNotEmpty;
      case AppConstants.providerOpenRouter:
        return openRouterKey.trim().isNotEmpty;
      case AppConstants.providerLocal:
        return true; // Local does not require an API key
      default:
        return false;
    }
  }

  ApiKeysModel copyWith({
    String? geminiKey,
    String? openAiKey,
    String? anthropicKey,
    String? groqKey,
    String? openRouterKey,
    String? openRouterBaseUrl,
    String? localAiBaseUrl,
    String? localAiModel,
    String? selectedProvider,
    String? selectedModel,
    String? sttMode,
  }) {
    return ApiKeysModel(
      geminiKey: geminiKey ?? this.geminiKey,
      openAiKey: openAiKey ?? this.openAiKey,
      anthropicKey: anthropicKey ?? this.anthropicKey,
      groqKey: groqKey ?? this.groqKey,
      openRouterKey: openRouterKey ?? this.openRouterKey,
      openRouterBaseUrl: openRouterBaseUrl ?? this.openRouterBaseUrl,
      localAiBaseUrl: localAiBaseUrl ?? this.localAiBaseUrl,
      localAiModel: localAiModel ?? this.localAiModel,
      selectedProvider: selectedProvider ?? this.selectedProvider,
      selectedModel: selectedModel ?? this.selectedModel,
      sttMode: sttMode ?? this.sttMode,
    );
  }

  @override
  List<Object?> get props => [
        geminiKey,
        openAiKey,
        anthropicKey,
        groqKey,
        openRouterKey,
        openRouterBaseUrl,
        localAiBaseUrl,
        localAiModel,
        selectedProvider,
        selectedModel,
        sttMode,
      ];
}
