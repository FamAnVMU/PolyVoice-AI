class AppConstants {
  static const String appName = 'PolyVoice AI';
  static const String appTagline = 'Client-Side Conversational Voice Companion';

  // LLM Providers
  static const String providerGemini = 'gemini';
  static const String providerGroq = 'groq';
  static const String providerOpenRouter = 'openrouter';

  // Default Models
  static const String defaultGeminiModel = 'gemini-1.5-flash';
  static const String defaultGroqModel = 'llama-3.3-70b-versatile';
  static const String defaultOpenRouterModel = 'meta-llama/llama-3.3-70b-instruct';

  // STT Modes
  static const String sttModeOnDevice = 'on_device';
  static const String sttModeGroqWhisper = 'groq_whisper';

  // Voice Engines
  static const String voiceEngineNeural = 'neural';
  static const String voiceEngineElevenLabs = 'elevenlabs';
  static const String voiceEngineDevice = 'device';

  // Default Voice Settings - Human-like Natural Conversational Pacing
  static const double defaultPitch = 1.0;
  static const double defaultRate = 0.88; // Relaxed natural conversational speed (no rap)
  static const double defaultVolume = 1.0;
  static const String defaultLanguage = 'vi-VN';
  static const String defaultVoiceId = 'preset_khanh_linh';

  // Storage Keys
  static const String keyGeminiApiKey = 'polyvoice_gemini_api_key';
  static const String keyGroqApiKey = 'polyvoice_groq_api_key';
  static const String keyOpenRouterApiKey = 'polyvoice_openrouter_api_key';
  static const String keyOpenRouterBaseUrl = 'polyvoice_openrouter_base_url';
  static const String keyElevenLabsApiKey = 'polyvoice_elevenlabs_api_key';
  static const String keyCustomVoices = 'polyvoice_custom_voices';

  static const String keySelectedProvider = 'polyvoice_selected_provider';
  static const String keySelectedModel = 'polyvoice_selected_model';
  static const String keyActivePersonaId = 'polyvoice_active_persona_id';
  static const String keyCustomPersonas = 'polyvoice_custom_personas';
  static const String keyVoiceConfig = 'polyvoice_voice_config';
  static const String keySttMode = 'polyvoice_stt_mode';
  static const String keyThemeMode = 'polyvoice_theme_mode';
  static const String keyChatHistory = 'polyvoice_chat_sessions';
}
