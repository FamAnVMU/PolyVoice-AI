import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../services/llm/llm_service_factory.dart';
import '../../../../services/storage/secure_storage_service.dart';
import '../../../../services/storage/voice_storage_service.dart';
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
  final VoiceStorageService voiceStorage;

  SettingsBloc({
    required this.secureStorage,
    required this.prefs,
    required this.ttsService,
    required this.llmFactory,
    VoiceStorageService? customVoiceStorage,
  })  : voiceStorage = customVoiceStorage ?? VoiceStorageService(prefs),
        super(SettingsState(
          activePersona: PersonaModel.defaultPresets.first,
        )) {
    on<LoadSettingsEvent>(_onLoadSettings);
    on<UpdateApiKeysEvent>(_onUpdateApiKeys);
    on<TestApiKeyConnectionEvent>(_onTestApiKeyConnection);
    on<DeleteProviderKeyEvent>(_onDeleteProviderKey);
    on<DismissApiNotificationEvent>(_onDismissApiNotification);
    on<SelectPersonaEvent>(_onSelectPersona);
    on<SaveCustomPersonaEvent>(_onSaveCustomPersona);
    on<DeleteCustomPersonaEvent>(_onDeleteCustomPersona);
    on<UpdateVoiceConfigEvent>(_onUpdateVoiceConfig);
    on<LoadAvailableVoicesEvent>(_onLoadAvailableVoices);
    on<SaveCustomVoiceEvent>(_onSaveCustomVoice);
    on<DeleteCustomVoiceEvent>(_onDeleteCustomVoice);
    on<SelectVoiceModelEvent>(_onSelectVoiceModel);
    on<ToggleThemeModeEvent>(_onToggleThemeMode);
    on<TestAllApiKeysEvent>(_onTestAllApiKeys);
  }

  String _getProviderDisplayName(String provider) {
    switch (provider) {
      case AppConstants.providerOpenAi:
        return 'OpenAI';
      case AppConstants.providerAnthropic:
        return 'Anthropic Claude';
      case AppConstants.providerGroq:
        return 'Groq Cloud';
      case AppConstants.providerOpenRouter:
        return 'OpenRouter';
      case AppConstants.providerLocal:
        return 'AI Local';
      case AppConstants.providerGemini:
      default:
        return 'Google Gemini';
    }
  }

  Future<void> _onLoadSettings(
    LoadSettingsEvent event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));

    // Load API Keys from Secure Storage with SharedPreferences backup fallback
    String geminiKey = '';
    String openAiKey = '';
    String anthropicKey = '';
    String groqKey = '';
    String openRouterKey = '';
    String openRouterBaseUrl = 'https://openrouter.ai/api/v1';
    String localAiBaseUrl = 'http://127.0.0.1:11434';
    String localAiModel = AppConstants.defaultLocalModel;

    try {
      geminiKey = await secureStorage.getGeminiKey() ?? '';
      if (geminiKey.isEmpty) {
        geminiKey = prefs.getString('polyvoice_backup_gemini_key') ?? '';
      }

      openAiKey = await secureStorage.getOpenAiKey() ?? '';
      if (openAiKey.isEmpty) {
        openAiKey = prefs.getString('polyvoice_backup_openai_key') ?? '';
      }

      anthropicKey = await secureStorage.getAnthropicKey() ?? '';
      if (anthropicKey.isEmpty) {
        anthropicKey = prefs.getString('polyvoice_backup_anthropic_key') ?? '';
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

      localAiBaseUrl = await secureStorage.getLocalAiBaseUrl() ??
          prefs.getString(AppConstants.keyLocalAiBaseUrl) ??
          'http://127.0.0.1:11434';

      localAiModel = prefs.getString(AppConstants.keyLocalAiModel) ?? AppConstants.defaultLocalModel;
    } catch (_) {}

    final selectedProvider =
        prefs.getString(AppConstants.keySelectedProvider) ?? AppConstants.providerGemini;
    final selectedModel =
        prefs.getString(AppConstants.keySelectedModel) ?? AppConstants.defaultGeminiModel;
    final sttMode =
        prefs.getString(AppConstants.keySttMode) ?? AppConstants.sttModeOnDevice;

    final apiKeys = ApiKeysModel(
      geminiKey: geminiKey,
      openAiKey: openAiKey,
      anthropicKey: anthropicKey,
      groqKey: groqKey,
      openRouterKey: openRouterKey,
      openRouterBaseUrl: openRouterBaseUrl,
      localAiBaseUrl: localAiBaseUrl,
      localAiModel: localAiModel,
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

    // Load Voice Config & ElevenLabs key
    VoiceConfigModel voiceConfig = const VoiceConfigModel();
    final voiceConfigJson = prefs.getString(AppConstants.keyVoiceConfig);
    if (voiceConfigJson != null) {
      try {
        voiceConfig = VoiceConfigModel.fromJson(
            jsonDecode(voiceConfigJson) as Map<String, dynamic>);
      } catch (_) {}
    }

    try {
      final elevenLabsKey = await secureStorage.getElevenLabsKey() ??
          prefs.getString('polyvoice_backup_elevenlabs_key') ?? '';
      voiceConfig = voiceConfig.copyWith(elevenLabsApiKey: elevenLabsKey);
    } catch (_) {}

    // Load Custom Voices from persistent storage
    final customVoices = voiceStorage.loadCustomVoices();

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
      customVoices: customVoices,
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
    if (keys.openAiKey.isNotEmpty) {
      await secureStorage.saveOpenAiKey(keys.openAiKey);
      await prefs.setString('polyvoice_backup_openai_key', keys.openAiKey);
    }
    if (keys.anthropicKey.isNotEmpty) {
      await secureStorage.saveAnthropicKey(keys.anthropicKey);
      await prefs.setString('polyvoice_backup_anthropic_key', keys.anthropicKey);
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
    if (keys.localAiBaseUrl.isNotEmpty) {
      await secureStorage.saveLocalAiBaseUrl(keys.localAiBaseUrl);
      await prefs.setString(AppConstants.keyLocalAiBaseUrl, keys.localAiBaseUrl);
    }
    await prefs.setString(AppConstants.keyLocalAiModel, keys.localAiModel);

    // Save Provider Preferences
    await prefs.setString(AppConstants.keySelectedProvider, keys.selectedProvider);
    await prefs.setString(AppConstants.keySelectedModel, keys.selectedModel);
    await prefs.setString(AppConstants.keySttMode, keys.sttMode);

    emit(state.copyWith(
      apiKeys: keys,
      activeNotification: ApiNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        provider: keys.selectedProvider,
        providerName: _getProviderDisplayName(keys.selectedProvider),
        type: ApiNotificationType.success,
        title: 'Đã lưu cấu hình an toàn',
        message: 'Các API Key đã được mã hóa an toàn trên thiết bị (Zero Server Cost).',
        timestamp: DateTime.now(),
      ),
    ));
  }

  Future<void> _onDeleteProviderKey(
    DeleteProviderKeyEvent event,
    Emitter<SettingsState> emit,
  ) async {
    final p = event.provider;
    final displayName = _getProviderDisplayName(p);
    ApiKeysModel updated = state.apiKeys;

    if (p == AppConstants.providerGemini) {
      await secureStorage.deleteGeminiKey();
      await prefs.remove('polyvoice_backup_gemini_key');
      updated = updated.copyWith(geminiKey: '');
    } else if (p == AppConstants.providerOpenAi) {
      await secureStorage.deleteOpenAiKey();
      await prefs.remove('polyvoice_backup_openai_key');
      updated = updated.copyWith(openAiKey: '');
    } else if (p == AppConstants.providerAnthropic) {
      await secureStorage.deleteAnthropicKey();
      await prefs.remove('polyvoice_backup_anthropic_key');
      updated = updated.copyWith(anthropicKey: '');
    } else if (p == AppConstants.providerGroq) {
      await secureStorage.deleteGroqKey();
      await prefs.remove('polyvoice_backup_groq_key');
      updated = updated.copyWith(groqKey: '');
    } else if (p == AppConstants.providerOpenRouter) {
      await secureStorage.deleteOpenRouterKey();
      await prefs.remove('polyvoice_backup_openrouter_key');
      updated = updated.copyWith(openRouterKey: '');
    } else if (p == 'elevenlabs') {
      await secureStorage.deleteElevenLabsKey();
      await prefs.remove('polyvoice_backup_elevenlabs_key');
      final updatedVoice = state.voiceConfig.copyWith(elevenLabsApiKey: '');
      emit(state.copyWith(voiceConfig: updatedVoice));
    }

    final updatedStatuses = Map<String, ApiTestStatus>.from(state.providerTestStatus);
    updatedStatuses.remove(p);
    final updatedMessages = Map<String, String>.from(state.providerTestMessage);
    updatedMessages.remove(p);

    emit(state.copyWith(
      apiKeys: updated,
      providerTestStatus: updatedStatuses,
      providerTestMessage: updatedMessages,
      activeNotification: ApiNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        provider: p,
        providerName: displayName,
        type: ApiNotificationType.warning,
        title: 'Đã xóa API Key',
        message: 'Khóa API của $displayName đã được xóa an toàn khỏi bộ nhớ thiết bị.',
        timestamp: DateTime.now(),
      ),
    ));
  }

  void _onDismissApiNotification(
    DismissApiNotificationEvent event,
    Emitter<SettingsState> emit,
  ) {
    emit(state.copyWith(clearNotification: true));
  }

  Future<void> _onTestApiKeyConnection(
    TestApiKeyConnectionEvent event,
    Emitter<SettingsState> emit,
  ) async {
    final p = event.provider;
    final displayName = _getProviderDisplayName(p);
    final modelName = event.model ?? 'Mặc định';

    final updatedStatuses = Map<String, ApiTestStatus>.from(state.providerTestStatus);
    final updatedMessages = Map<String, String>.from(state.providerTestMessage);

    updatedStatuses[p] = ApiTestStatus.testing;
    updatedMessages[p] = 'Đang kiểm tra kết nối...';

    // 1. Emit instant checking floating notification
    emit(state.copyWith(
      providerTestStatus: updatedStatuses,
      providerTestMessage: updatedMessages,
      testStatus: ApiTestStatus.testing,
      testResultMessage: 'Đang kiểm tra $displayName...',
      activeNotification: ApiNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        provider: p,
        providerName: displayName,
        type: ApiNotificationType.checking,
        title: 'Đang kiểm tra API...',
        message: 'Đang gửi yêu cầu xác thực kết nối tới $displayName...',
        modelTested: modelName,
        timestamp: DateTime.now(),
      ),
    ));

    try {
      final providerService = llmFactory.getProvider(p);
      final isSuccess = await providerService.testConnection(
        apiKey: event.apiKey,
        model: event.model,
        customBaseUrl: event.baseUrl,
      );

      if (isSuccess) {
        updatedStatuses[p] = ApiTestStatus.success;
        updatedMessages[p] = 'Kết nối thành công (Model: $modelName)';

        emit(state.copyWith(
          providerTestStatus: updatedStatuses,
          providerTestMessage: updatedMessages,
          testStatus: ApiTestStatus.success,
          testResultMessage: '✓ Kết nối thành công! Khóa API của $displayName hợp lệ.',
          activeNotification: ApiNotification(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            provider: p,
            providerName: displayName,
            type: ApiNotificationType.success,
            title: 'Kết nối API thành công!',
            message: 'Đã xác thực thành công với $displayName. Mô hình "$modelName" đã sẵn sàng phục vụ.',
            modelTested: modelName,
            timestamp: DateTime.now(),
          ),
        ));
      } else {
        updatedStatuses[p] = ApiTestStatus.failed;
        updatedMessages[p] = 'Không thể xác thực phản hồi từ $displayName';

        emit(state.copyWith(
          providerTestStatus: updatedStatuses,
          providerTestMessage: updatedMessages,
          testStatus: ApiTestStatus.failed,
          testResultMessage: '✗ Kết nối thất bại. Vui lòng kiểm tra lại khóa API.',
          activeNotification: ApiNotification(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            provider: p,
            providerName: displayName,
            type: ApiNotificationType.error,
            title: 'Kết nối thất bại',
            message: 'Không nhận được phản hồi hợp lệ từ máy chủ $displayName. Vui lòng kiểm tra lại API Key.',
            modelTested: modelName,
            timestamp: DateTime.now(),
          ),
        ));
      }
    } catch (e) {
      final errorStr = e.toString().replaceFirst('Exception: ', '').replaceFirst('Failure: ', '');
      String cleanReason = errorStr;

      // Extract specific friendly reasons
      if (errorStr.contains('401') || errorStr.toLowerCase().contains('unauthorized') || errorStr.toLowerCase().contains('invalid')) {
        cleanReason = 'Khóa API Key không hợp lệ hoặc đã hết hạn. Vui lòng kiểm tra lại ký tự API Key.';
      } else if (errorStr.contains('429') || errorStr.toLowerCase().contains('quota') || errorStr.toLowerCase().contains('rate limit')) {
        cleanReason = 'Tài khoản $displayName đã hết hạn mức credit (Quota) hoặc vượt giới hạn tần suất gửi.';
      } else if (errorStr.contains('404') || errorStr.toLowerCase().contains('not found')) {
        cleanReason = 'Mô hình "$modelName" không tồn tại hoặc tài khoản chưa có quyền truy cập.';
      } else if (errorStr.toLowerCase().contains('timeout') || errorStr.toLowerCase().contains('network') || errorStr.toLowerCase().contains('kết nối')) {
        cleanReason = 'Không thể kết nối đến máy chủ $displayName. Vui lòng kiểm tra kết nối mạng Internet.';
      }

      updatedStatuses[p] = ApiTestStatus.failed;
      updatedMessages[p] = cleanReason;

      emit(state.copyWith(
        providerTestStatus: updatedStatuses,
        providerTestMessage: updatedMessages,
        testStatus: ApiTestStatus.failed,
        testResultMessage: '✗ $cleanReason',
        activeNotification: ApiNotification(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          provider: p,
          providerName: displayName,
          type: ApiNotificationType.error,
          title: 'Kết nối $displayName thất bại',
          message: cleanReason,
          modelTested: modelName,
          timestamp: DateTime.now(),
        ),
      ));
    }
  }

  Future<void> _onTestAllApiKeys(
    TestAllApiKeysEvent event,
    Emitter<SettingsState> emit,
  ) async {
    final keys = state.apiKeys;
    final Map<String, String> keysToTest = {};

    if (keys.geminiKey.trim().isNotEmpty) keysToTest[AppConstants.providerGemini] = keys.geminiKey.trim();
    if (keys.openAiKey.trim().isNotEmpty) keysToTest[AppConstants.providerOpenAi] = keys.openAiKey.trim();
    if (keys.anthropicKey.trim().isNotEmpty) keysToTest[AppConstants.providerAnthropic] = keys.anthropicKey.trim();
    if (keys.groqKey.trim().isNotEmpty) keysToTest[AppConstants.providerGroq] = keys.groqKey.trim();
    if (keys.openRouterKey.trim().isNotEmpty) keysToTest[AppConstants.providerOpenRouter] = keys.openRouterKey.trim();
    if (state.voiceConfig.elevenLabsApiKey.trim().isNotEmpty) {
      keysToTest['elevenlabs'] = state.voiceConfig.elevenLabsApiKey.trim();
    }

    if (keysToTest.isEmpty) {
      emit(state.copyWith(
        activeNotification: ApiNotification(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          provider: 'all',
          providerName: 'Hệ thống API',
          type: ApiNotificationType.warning,
          title: 'Chưa có API Key nào được cấu hình',
          message: 'Vui lòng nhập ít nhất một API Key để tiến hành kiểm tra kết nối.',
          timestamp: DateTime.now(),
        ),
      ));
      return;
    }

    final updatedStatuses = Map<String, ApiTestStatus>.from(state.providerTestStatus);
    final updatedMessages = Map<String, String>.from(state.providerTestMessage);

    for (final p in keysToTest.keys) {
      updatedStatuses[p] = ApiTestStatus.testing;
      updatedMessages[p] = 'Đang kiểm tra kết nối...';
    }

    emit(state.copyWith(
      providerTestStatus: updatedStatuses,
      providerTestMessage: updatedMessages,
      activeNotification: ApiNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        provider: 'all',
        providerName: 'Tất cả API',
        type: ApiNotificationType.checking,
        title: 'Đang kiểm tra toàn bộ API Key...',
        message: 'Đang tiến hành kiểm tra đồng thời ${keysToTest.length} API Key đã cấu hình...',
        timestamp: DateTime.now(),
      ),
    ));

    int successCount = 0;
    int failedCount = 0;

    for (final entry in keysToTest.entries) {
      final p = entry.key;
      final key = entry.value;

      try {
        bool isOk = false;
        if (p == 'elevenlabs') {
          // ElevenLabs direct verification
          isOk = await ttsService.elevenLabsService.testConnection(key);
        } else {
          final providerService = llmFactory.getProvider(p);
          isOk = await providerService.testConnection(
            apiKey: key,
            customBaseUrl: p == AppConstants.providerOpenRouter ? keys.openRouterBaseUrl : null,
          );
        }

        if (isOk) {
          successCount++;
          updatedStatuses[p] = ApiTestStatus.success;
          updatedMessages[p] = '✓ Kết nối thành công';
        } else {
          failedCount++;
          updatedStatuses[p] = ApiTestStatus.failed;
          updatedMessages[p] = '✗ Phản hồi không hợp lệ';
        }
      } catch (e) {
        failedCount++;
        updatedStatuses[p] = ApiTestStatus.failed;
        final errorStr = e.toString().replaceFirst('Exception: ', '');
        if (errorStr.contains('401') || errorStr.toLowerCase().contains('unauthorized')) {
          updatedMessages[p] = '✗ API Key không hợp lệ hoặc hết hạn';
        } else if (errorStr.contains('429')) {
          updatedMessages[p] = '✗ Hết quota hoặc chạm rate-limit';
        } else {
          updatedMessages[p] = '✗ Lỗi kết nối';
        }
      }

      emit(state.copyWith(
        providerTestStatus: Map<String, ApiTestStatus>.from(updatedStatuses),
        providerTestMessage: Map<String, String>.from(updatedMessages),
      ));
    }

    final isAllSuccess = failedCount == 0;
    emit(state.copyWith(
      providerTestStatus: updatedStatuses,
      providerTestMessage: updatedMessages,
      activeNotification: ApiNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        provider: 'all',
        providerName: 'Tổng hợp API',
        type: isAllSuccess ? ApiNotificationType.success : (successCount > 0 ? ApiNotificationType.warning : ApiNotificationType.error),
        title: isAllSuccess
            ? 'Tất cả API Key hoạt động tốt! ($successCount/${keysToTest.length})'
            : 'Kiểm tra hoàn tất: $successCount thành công, $failedCount thất bại',
        message: isAllSuccess
            ? 'Đã xác thực thành công toàn bộ $successCount dịch vụ AI. Ứng dụng đã sẵn sàng.'
            : 'Phát hiện $failedCount API Key gặp lỗi hoặc hết hạn ngạch. Vui lòng xem chi tiết bên dưới.',
        timestamp: DateTime.now(),
      ),
    ));
  }

  Future<void> _onSelectPersona(
    SelectPersonaEvent event,
    Emitter<SettingsState> emit,
  ) async {
    await prefs.setString(AppConstants.keyActivePersonaId, event.persona.id);

    final updatedVoiceConfig = state.voiceConfig.copyWith(
      pitch: event.persona.defaultPitch,
      rate: event.persona.defaultRate,
      languageCode: event.persona.languageCode,
    );

    emit(state.copyWith(
      activePersona: event.persona,
      voiceConfig: updatedVoiceConfig,
    ));
  }

  Future<void> _onSaveCustomPersona(
    SaveCustomPersonaEvent event,
    Emitter<SettingsState> emit,
  ) async {
    final personas = List<PersonaModel>.from(state.personas);
    final index = personas.indexWhere((p) => p.id == event.persona.id);

    if (index >= 0) {
      personas[index] = event.persona;
    } else {
      personas.add(event.persona);
    }

    final customOnly = personas.where((p) => !p.isBuiltIn).toList();
    final jsonStr = jsonEncode(customOnly.map((p) => p.toJson()).toList());
    await prefs.setString(AppConstants.keyCustomPersonas, jsonStr);

    emit(state.copyWith(personas: personas));
  }

  Future<void> _onDeleteCustomPersona(
    DeleteCustomPersonaEvent event,
    Emitter<SettingsState> emit,
  ) async {
    final personas = List<PersonaModel>.from(state.personas);
    personas.removeWhere((p) => p.id == event.personaId && !p.isBuiltIn);

    final customOnly = personas.where((p) => !p.isBuiltIn).toList();
    final jsonStr = jsonEncode(customOnly.map((p) => p.toJson()).toList());
    await prefs.setString(AppConstants.keyCustomPersonas, jsonStr);

    PersonaModel active = state.activePersona;
    if (active.id == event.personaId) {
      active = personas.first;
      await prefs.setString(AppConstants.keyActivePersonaId, active.id);
    }

    emit(state.copyWith(personas: personas, activePersona: active));
  }

  Future<void> _onUpdateVoiceConfig(
    UpdateVoiceConfigEvent event,
    Emitter<SettingsState> emit,
  ) async {
    final config = event.voiceConfig;
    await prefs.setString(AppConstants.keyVoiceConfig, jsonEncode(config.toJson()));

    if (config.elevenLabsApiKey.isNotEmpty) {
      await secureStorage.saveElevenLabsKey(config.elevenLabsApiKey);
      await prefs.setString('polyvoice_backup_elevenlabs_key', config.elevenLabsApiKey);
    }

    emit(state.copyWith(voiceConfig: config));
  }

  Future<void> _onLoadAvailableVoices(
    LoadAvailableVoicesEvent event,
    Emitter<SettingsState> emit,
  ) async {
    final voices = await ttsService.getAvailableVoices(
      filterLanguageCode: event.languageCode,
    );
    emit(state.copyWith(availableVoices: voices));
  }

  Future<void> _onSaveCustomVoice(
    SaveCustomVoiceEvent event,
    Emitter<SettingsState> emit,
  ) async {
    await voiceStorage.saveCustomVoice(event.voice);
    final customVoices = voiceStorage.loadCustomVoices();
    emit(state.copyWith(customVoices: customVoices));
  }

  Future<void> _onDeleteCustomVoice(
    DeleteCustomVoiceEvent event,
    Emitter<SettingsState> emit,
  ) async {
    await voiceStorage.deleteCustomVoice(event.voiceId);
    final customVoices = voiceStorage.loadCustomVoices();

    String currentVoiceId = state.voiceConfig.activeVoiceId;
    if (currentVoiceId == event.voiceId) {
      currentVoiceId = AppConstants.defaultVoiceId;
      final updated = state.voiceConfig.copyWith(activeVoiceId: currentVoiceId);
      await prefs.setString(AppConstants.keyVoiceConfig, jsonEncode(updated.toJson()));
      emit(state.copyWith(voiceConfig: updated, customVoices: customVoices));
      return;
    }

    emit(state.copyWith(customVoices: customVoices));
  }

  Future<void> _onSelectVoiceModel(
    SelectVoiceModelEvent event,
    Emitter<SettingsState> emit,
  ) async {
    final updated = state.voiceConfig.copyWith(activeVoiceId: event.voiceId);
    await prefs.setString(AppConstants.keyVoiceConfig, jsonEncode(updated.toJson()));
    emit(state.copyWith(voiceConfig: updated));
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
