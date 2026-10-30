import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../data/models/api_keys_model.dart';
import '../../data/models/persona_model.dart';
import '../../data/models/voice_config_model.dart';

enum ApiTestStatus { idle, testing, success, failed }

class SettingsState extends Equatable {
  final bool isLoading;
  final ApiKeysModel apiKeys;
  final List<PersonaModel> personas;
  final PersonaModel activePersona;
  final VoiceConfigModel voiceConfig;
  final List<Map<String, String>> availableVoices;
  final ThemeMode themeMode;
  final ApiTestStatus testStatus;
  final String? testResultMessage;
  final String? errorMessage;

  const SettingsState({
    this.isLoading = false,
    this.apiKeys = const ApiKeysModel(),
    this.personas = const [],
    required this.activePersona,
    this.voiceConfig = const VoiceConfigModel(),
    this.availableVoices = const [],
    this.themeMode = ThemeMode.dark,
    this.testStatus = ApiTestStatus.idle,
    this.testResultMessage,
    this.errorMessage,
  });

  SettingsState copyWith({
    bool? isLoading,
    ApiKeysModel? apiKeys,
    List<PersonaModel>? personas,
    PersonaModel? activePersona,
    VoiceConfigModel? voiceConfig,
    List<Map<String, String>>? availableVoices,
    ThemeMode? themeMode,
    ApiTestStatus? testStatus,
    String? testResultMessage,
    String? errorMessage,
  }) {
    return SettingsState(
      isLoading: isLoading ?? this.isLoading,
      apiKeys: apiKeys ?? this.apiKeys,
      personas: personas ?? this.personas,
      activePersona: activePersona ?? this.activePersona,
      voiceConfig: voiceConfig ?? this.voiceConfig,
      availableVoices: availableVoices ?? this.availableVoices,
      themeMode: themeMode ?? this.themeMode,
      testStatus: testStatus ?? this.testStatus,
      testResultMessage: testResultMessage,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        apiKeys,
        personas,
        activePersona,
        voiceConfig,
        availableVoices,
        themeMode,
        testStatus,
        testResultMessage,
        errorMessage,
      ];
}
