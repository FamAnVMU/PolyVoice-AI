import 'package:equatable/equatable.dart';
import '../../../voice/data/models/voice_model.dart';
import '../../data/models/api_keys_model.dart';
import '../../data/models/persona_model.dart';
import '../../data/models/voice_config_model.dart';

abstract class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

class LoadSettingsEvent extends SettingsEvent {}

class UpdateApiKeysEvent extends SettingsEvent {
  final ApiKeysModel apiKeys;
  const UpdateApiKeysEvent(this.apiKeys);

  @override
  List<Object?> get props => [apiKeys];
}

class TestApiKeyConnectionEvent extends SettingsEvent {
  final String provider;
  final String apiKey;
  final String? model;
  final String? baseUrl;

  const TestApiKeyConnectionEvent({
    required this.provider,
    required this.apiKey,
    this.model,
    this.baseUrl,
  });

  @override
  List<Object?> get props => [provider, apiKey, model, baseUrl];
}

class SelectPersonaEvent extends SettingsEvent {
  final PersonaModel persona;
  const SelectPersonaEvent(this.persona);

  @override
  List<Object?> get props => [persona];
}

class SaveCustomPersonaEvent extends SettingsEvent {
  final PersonaModel persona;
  const SaveCustomPersonaEvent(this.persona);

  @override
  List<Object?> get props => [persona];
}

class DeleteCustomPersonaEvent extends SettingsEvent {
  final String personaId;
  const DeleteCustomPersonaEvent(this.personaId);

  @override
  List<Object?> get props => [personaId];
}

class UpdateVoiceConfigEvent extends SettingsEvent {
  final VoiceConfigModel voiceConfig;
  const UpdateVoiceConfigEvent(this.voiceConfig);

  @override
  List<Object?> get props => [voiceConfig];
}

class LoadAvailableVoicesEvent extends SettingsEvent {
  final String languageCode;
  const LoadAvailableVoicesEvent(this.languageCode);

  @override
  List<Object?> get props => [languageCode];
}

class SaveCustomVoiceEvent extends SettingsEvent {
  final VoiceModel voice;
  const SaveCustomVoiceEvent(this.voice);

  @override
  List<Object?> get props => [voice];
}

class DeleteCustomVoiceEvent extends SettingsEvent {
  final String voiceId;
  const DeleteCustomVoiceEvent(this.voiceId);

  @override
  List<Object?> get props => [voiceId];
}

class SelectVoiceModelEvent extends SettingsEvent {
  final String voiceId;
  const SelectVoiceModelEvent(this.voiceId);

  @override
  List<Object?> get props => [voiceId];
}

class ToggleThemeModeEvent extends SettingsEvent {}
