import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../services/llm/llm_service_factory.dart';
import '../../../../services/storage/secure_storage_service.dart';
import '../../../../services/voice/tts_service.dart';
import '../../data/models/api_keys_model.dart';
import '../../data/models/persona_model.dart';
import '../../data/models/voice_config_model.dart';
import 'settings_event.dart';
import 'settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final SecureStorageService secureStorage;
  final SharedPreferences prefs;
  final TtsService ttsService;
  final LlmServiceFactory llmFactory;

  SettingsBloc({
    required this.secureStorage,
    required this.prefs,
    required this.ttsService,
    required this.llmFactory,
  }) : super(SettingsState(
          activePersona: PersonaModel.defaultPresets.first,
        )) {
    on<LoadSettingsEvent>(_onLoadSettings);
    on<UpdateApiKeysEvent>(_onUpdateApiKeys);
    on<TestApiKeyConnectionEvent>(_onTestApiKeyConnection);
    on<SelectPersonaEvent>(_onSelectPersona);
    on<SaveCustomPersonaEvent>(_onSaveCustomPersona);
    on<DeleteCustomPersonaEvent>(_onDeleteCustomPersona);
    on<UpdateVoiceConfigEvent>(_onUpdateVoiceConfig);
    on<LoadAvailableVoicesEvent>(_onLoadAvailableVoices);
    on<ToggleThemeModeEvent>(_onToggleThemeMode);
  }

  Future<void> _onLoadSettings(
    LoadSettingsEvent event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));

    // Load API Keys from Secure Storage with SharedPreferences backup fallback
    String geminiKey = '';
    String groqKey = '';
    String openRouterKey = '';
    String openRouterBaseUrl = 'https://openrouter.ai/api/v1';

    try {
      geminiKey = await secureStorage.getGeminiKey() ?? '';
      if (geminiKey.isEmpty) {
        geminiKey = prefs.getString('polyvoice_backup_gemini_key') ?? '';
      }

      groqKey = await secureStorage.getGroqKey() ?? '';
      if (groqKey.isEmpty) {
        groqKey = prefs.getString('polyvoice_backup_groq_key') ?? '';
      }

      openRouterKey = await secureStorage.getOpenRouterKey() ?? '';
      if (openRouterKey.isEmpty) {
        openRouterKey = prefs.getString('polyvoice_backup_openrouter_key') ?? '';
      }

      openRouterBaseUrl = await secureStorage.getOpenRouterBaseUrl() ??
          prefs.getString(AppConstants.keyOpenRouterBaseUrl) ??
          'https://openrouter.ai/api/v1';
    } catch (_) {}

    final selectedProvider =
        prefs.getString(AppConstants.keySelectedProvider) ?? AppConstants.providerGemini;
    final selectedModel =
        prefs.getString(AppConstants.keySelectedModel) ?? AppConstants.defaultGeminiModel;
    final sttMode =
        prefs.getString(AppConstants.keySttMode) ?? AppConstants.sttModeOnDevice;

    final apiKeys = ApiKeysModel(
      geminiKey: geminiKey,
      groqKey: groqKey,
      openRouterKey: openRouterKey,
      openRouterBaseUrl: openRouterBaseUrl,
      selectedProvider: selectedProvider,
      selectedModel: selectedModel,
      sttMode: sttMode,
    );

    // Load Personas
    final List<PersonaModel> personas = [...PersonaModel.defaultPresets];
    final customPersonasJson = prefs.getString(AppConstants.keyCustomPersonas);
    if (customPersonasJson != null) {
      try {
        final List<dynamic> customList = jsonDecode(customPersonasJson) as List<dynamic>;
        for (final item in customList) {
          personas.add(PersonaModel.fromJson(item as Map<String, dynamic>));
        }
      } catch (_) {}
    }

    final activePersonaId = prefs.getString(AppConstants.keyActivePersonaId);
    final activePersona = personas.firstWhere(
      (p) => p.id == activePersonaId,
      orElse: () => personas.first,
    );

    // Load Voice Config
    VoiceConfigModel voiceConfig = const VoiceConfigModel();
    final voiceConfigJson = prefs.getString(AppConstants.keyVoiceConfig);
    if (voiceConfigJson != null) {
      try {
        voiceConfig = VoiceConfigModel.fromJson(
            jsonDecode(voiceConfigJson) as Map<String, dynamic>);
      } catch (_) {}
    }

    // Load Theme Mode
    final themeModeStr = prefs.getString(AppConstants.keyThemeMode);
    final themeMode = themeModeStr == 'light' ? ThemeMode.light : ThemeMode.dark;

    // Load system voices for active language
    final voices = await ttsService.getAvailableVoices(
        filterLanguageCode: voiceConfig.languageCode);

    emit(state.copyWith(
      isLoading: false,
      apiKeys: apiKeys,
      personas: personas,
      activePersona: activePersona,
      voiceConfig: voiceConfig,
      availableVoices: voices,
      themeMode: themeMode,
    ));
  }

  Future<void> _onUpdateApiKeys(
    UpdateApiKeysEvent event,
    Emitter<SettingsState> emit,
  ) async {
    final keys = event.apiKeys;

    // Save to Secure Storage with persistent backup
    if (keys.geminiKey.isNotEmpty) {
      await secureStorage.saveGeminiKey(keys.geminiKey);
      await prefs.setString('polyvoice_backup_gemini_key', keys.geminiKey);
    }
    if (keys.groqKey.isNotEmpty) {
      await secureStorage.saveGroqKey(keys.groqKey);
      await prefs.setString('polyvoice_backup_groq_key', keys.groqKey);
    }
    if (keys.openRouterKey.isNotEmpty) {
      await secureStorage.saveOpenRouterKey(keys.openRouterKey);
      await prefs.setString('polyvoice_backup_openrouter_key', keys.openRouterKey);
    }
    if (keys.openRouterBaseUrl.isNotEmpty) {
      await secureStorage.saveOpenRouterBaseUrl(keys.openRouterBaseUrl);
      await prefs.setString(AppConstants.keyOpenRouterBaseUrl, keys.openRouterBaseUrl);
    }

    // Save Provider Preferences
    await prefs.setString(AppConstants.keySelectedProvider, keys.selectedProvider);
    await prefs.setString(AppConstants.keySelectedModel, keys.selectedModel);
    await prefs.setString(AppConstants.keySttMode, keys.sttMode);

    emit(state.copyWith(apiKeys: keys));
  }

  Future<void> _onTestApiKeyConnection(
    TestApiKeyConnectionEvent event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(
      testStatus: ApiTestStatus.testing,
      testResultMessage: 'Testing connection...',
    ));

    try {
      final provider = llmFactory.getProvider(event.provider);
      final isSuccess = await provider.testConnection(
        apiKey: event.apiKey,
        model: event.model,
        customBaseUrl: event.baseUrl,
      );

      if (isSuccess) {
        emit(state.copyWith(
          testStatus: ApiTestStatus.success,
          testResultMessage: '✓ Connected successfully! Key is valid.',
        ));
      } else {
        emit(state.copyWith(
          testStatus: ApiTestStatus.failed,
          testResultMessage: '✗ Connection failed. Please check your key.',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        testStatus: ApiTestStatus.failed,
        testResultMessage: '✗ Error: $e',
      ));
    }
  }

  Future<void> _onSelectPersona(
    SelectPersonaEvent event,
    Emitter<SettingsState> emit,
  ) async {
    await prefs.setString(AppConstants.keyActivePersonaId, event.persona.id);

    // Automatically adapt voice pitch and speed to selected persona
    final updatedVoiceConfig = state.voiceConfig.copyWith(
      pitch: event.persona.defaultPitch,
      rate: event.persona.defaultRate,
      languageCode: event.persona.languageCode,
    );

    await prefs.setString(
        AppConstants.keyVoiceConfig, jsonEncode(updatedVoiceConfig.toJson()));

    // Refresh voices for new language
    final voices = await ttsService.getAvailableVoices(
        filterLanguageCode: event.persona.languageCode);

    emit(state.copyWith(
      activePersona: event.persona,
      voiceConfig: updatedVoiceConfig,
      availableVoices: voices,
    ));
  }

  Future<void> _onSaveCustomPersona(
    SaveCustomPersonaEvent event,
    Emitter<SettingsState> emit,
  ) async {
    final List<PersonaModel> customOnly =
        state.personas.where((p) => !p.isBuiltIn).toList();

    final existingIndex =
        customOnly.indexWhere((p) => p.id == event.persona.id);
    if (existingIndex >= 0) {
      customOnly[existingIndex] = event.persona;
    } else {
      customOnly.add(event.persona);
    }

    await prefs.setString(AppConstants.keyCustomPersonas,
        jsonEncode(customOnly.map((p) => p.toJson()).toList()));

    final updatedAll = [...PersonaModel.defaultPresets, ...customOnly];
    emit(state.copyWith(
      personas: updatedAll,
      activePersona: event.persona,
    ));
  }

  Future<void> _onDeleteCustomPersona(
    DeleteCustomPersonaEvent event,
    Emitter<SettingsState> emit,
  ) async {
    final List<PersonaModel> customOnly = state.personas
        .where((p) => !p.isBuiltIn && p.id != event.personaId)
        .toList();

    await prefs.setString(AppConstants.keyCustomPersonas,
        jsonEncode(customOnly.map((p) => p.toJson()).toList()));

    final updatedAll = [...PersonaModel.defaultPresets, ...customOnly];
    final active = state.activePersona.id == event.personaId
        ? updatedAll.first
        : state.activePersona;

    emit(state.copyWith(
      personas: updatedAll,
      activePersona: active,
    ));
  }

  Future<void> _onUpdateVoiceConfig(
    UpdateVoiceConfigEvent event,
    Emitter<SettingsState> emit,
  ) async {
    await prefs.setString(
        AppConstants.keyVoiceConfig, jsonEncode(event.voiceConfig.toJson()));
    await ttsService.configureVoice(event.voiceConfig);

    emit(state.copyWith(voiceConfig: event.voiceConfig));
  }

  Future<void> _onLoadAvailableVoices(
    LoadAvailableVoicesEvent event,
    Emitter<SettingsState> emit,
  ) async {
    final voices = await ttsService.getAvailableVoices(
        filterLanguageCode: event.languageCode);
    emit(state.copyWith(availableVoices: voices));
  }

  Future<void> _onToggleThemeMode(
    ToggleThemeModeEvent event,
    Emitter<SettingsState> emit,
  ) async {
    final newMode =
        state.themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await prefs.setString(
        AppConstants.keyThemeMode, newMode == ThemeMode.light ? 'light' : 'dark');
    emit(state.copyWith(themeMode: newMode));
  }
}
