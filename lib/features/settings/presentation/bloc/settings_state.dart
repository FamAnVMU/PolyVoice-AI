import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../../voice/data/models/voice_model.dart';
import '../../data/models/api_keys_model.dart';
import '../../data/models/persona_model.dart';
import '../../data/models/voice_config_model.dart';

enum ApiTestStatus { idle, testing, success, failed }

enum ApiNotificationType { checking, success, error, warning }

class ApiNotification extends Equatable {
  final String id;
  final String provider;
  final String providerName;
  final ApiNotificationType type;
  final String title;
  final String message;
  final String? modelTested;
  final DateTime timestamp;

  const ApiNotification({
    required this.id,
    required this.provider,
    required this.providerName,
    required this.type,
    required this.title,
    required this.message,
    this.modelTested,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [
        id,
        provider,
        providerName,
        type,
        title,
        message,
        modelTested,
        timestamp,
      ];
}

class SettingsState extends Equatable {
  final bool isLoading;
  final ApiKeysModel apiKeys;
  final List<PersonaModel> personas;
  final PersonaModel activePersona;
  final VoiceConfigModel voiceConfig;
  final List<Map<String, String>> availableVoices;
  final List<VoiceModel> customVoices;
  final ThemeMode themeMode;

  // Global Floating Notification
  final ApiNotification? activeNotification;

  // Per-Provider Connection Test Status
  final Map<String, ApiTestStatus> providerTestStatus;
  final Map<String, String> providerTestMessage;

  // Legacy fallback fields for backward compatibility
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
    this.customVoices = const [],
    this.themeMode = ThemeMode.dark,
    this.activeNotification,
    this.providerTestStatus = const {},
    this.providerTestMessage = const {},
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
    List<VoiceModel>? customVoices,
    ThemeMode? themeMode,
    ApiNotification? activeNotification,
    bool clearNotification = false,
    Map<String, ApiTestStatus>? providerTestStatus,
    Map<String, String>? providerTestMessage,
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
      customVoices: customVoices ?? this.customVoices,
      themeMode: themeMode ?? this.themeMode,
      activeNotification: clearNotification
          ? null
          : (activeNotification ?? this.activeNotification),
      providerTestStatus: providerTestStatus ?? this.providerTestStatus,
      providerTestMessage: providerTestMessage ?? this.providerTestMessage,
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
        customVoices,
        themeMode,
        activeNotification,
        providerTestStatus,
        providerTestMessage,
        testStatus,
        testResultMessage,
        errorMessage,
      ];
}
