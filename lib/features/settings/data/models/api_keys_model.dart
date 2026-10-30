import 'package:equatable/equatable.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_constants.dart';

class ApiKeysModel extends Equatable {
  final String geminiKey;
  final String groqKey;
  final String openRouterKey;
  final String openRouterBaseUrl;
  final String selectedProvider;
  final String selectedModel;
  final String sttMode;

  const ApiKeysModel({
    this.geminiKey = '',
    this.groqKey = '',
    this.openRouterKey = '',
    this.openRouterBaseUrl = ApiEndpoints.defaultOpenRouterBaseUrl,
    this.selectedProvider = AppConstants.providerGemini,
    this.selectedModel = AppConstants.defaultGeminiModel,
    this.sttMode = AppConstants.sttModeOnDevice,
  });

  ApiKeysModel copyWith({
    String? geminiKey,
    String? groqKey,
    String? openRouterKey,
    String? openRouterBaseUrl,
    String? selectedProvider,
    String? selectedModel,
    String? sttMode,
  }) {
    return ApiKeysModel(
      geminiKey: geminiKey ?? this.geminiKey,
      groqKey: groqKey ?? this.groqKey,
      openRouterKey: openRouterKey ?? this.openRouterKey,
      openRouterBaseUrl: openRouterBaseUrl ?? this.openRouterBaseUrl,
      selectedProvider: selectedProvider ?? this.selectedProvider,
      selectedModel: selectedModel ?? this.selectedModel,
      sttMode: sttMode ?? this.sttMode,
    );
  }

  @override
  List<Object?> get props => [
        geminiKey,
        groqKey,
        openRouterKey,
        openRouterBaseUrl,
        selectedProvider,
        selectedModel,
        sttMode,
      ];
}
