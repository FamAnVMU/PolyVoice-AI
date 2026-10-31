import 'package:equatable/equatable.dart';
import '../../../../core/constants/app_constants.dart';

class VoiceConfigModel extends Equatable {
  final double pitch;
  final double rate;
  final double volume;
  final String languageCode;
  final String? voiceName;
  final String? voiceLocale;
  final String selectedVoiceId;
  final double emotion;
  final double stability;
  final double style;
  final String voiceEngine;
  final String emotionPreset;
  final String elevenLabsApiKey;

  String get activeVoiceId => selectedVoiceId;

  const VoiceConfigModel({
    this.pitch = AppConstants.defaultPitch,
    this.rate = AppConstants.defaultRate,
    this.volume = AppConstants.defaultVolume,
    this.languageCode = AppConstants.defaultLanguage,
    this.voiceName,
    this.voiceLocale,
    this.selectedVoiceId = AppConstants.defaultVoiceId,
    this.emotion = 0.70,
    this.stability = 0.60,
    this.style = 0.25,
    this.voiceEngine = AppConstants.voiceEngineNeural,
    this.emotionPreset = 'natural',
    this.elevenLabsApiKey = '',
  });

  VoiceConfigModel copyWith({
    double? pitch,
    double? rate,
    double? volume,
    String? languageCode,
    String? voiceName,
    String? voiceLocale,
    String? selectedVoiceId,
    String? activeVoiceId,
    double? emotion,
    double? stability,
    double? style,
    String? voiceEngine,
    String? emotionPreset,
    String? elevenLabsApiKey,
  }) {
    return VoiceConfigModel(
      pitch: pitch ?? this.pitch,
      rate: rate ?? this.rate,
      volume: volume ?? this.volume,
      languageCode: languageCode ?? this.languageCode,
      voiceName: voiceName ?? this.voiceName,
      voiceLocale: voiceLocale ?? this.voiceLocale,
      selectedVoiceId: selectedVoiceId ?? activeVoiceId ?? this.selectedVoiceId,
      emotion: emotion ?? this.emotion,
      stability: stability ?? this.stability,
      style: style ?? this.style,
      voiceEngine: voiceEngine ?? this.voiceEngine,
      emotionPreset: emotionPreset ?? this.emotionPreset,
      elevenLabsApiKey: elevenLabsApiKey ?? this.elevenLabsApiKey,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pitch': pitch,
      'rate': rate,
      'volume': volume,
      'languageCode': languageCode,
      'voiceName': voiceName,
      'voiceLocale': voiceLocale,
      'selectedVoiceId': selectedVoiceId,
      'emotion': emotion,
      'stability': stability,
      'style': style,
      'voiceEngine': voiceEngine,
      'emotionPreset': emotionPreset,
      'elevenLabsApiKey': elevenLabsApiKey,
    };
  }

  factory VoiceConfigModel.fromJson(Map<String, dynamic> json) {
    return VoiceConfigModel(
      pitch: (json['pitch'] as num?)?.toDouble() ?? AppConstants.defaultPitch,
      rate: (json['rate'] as num?)?.toDouble() ?? AppConstants.defaultRate,
      volume: (json['volume'] as num?)?.toDouble() ?? AppConstants.defaultVolume,
      languageCode: json['languageCode'] as String? ?? AppConstants.defaultLanguage,
      voiceName: json['voiceName'] as String?,
      voiceLocale: json['voiceLocale'] as String?,
      selectedVoiceId: json['selectedVoiceId'] as String? ?? AppConstants.defaultVoiceId,
      emotion: (json['emotion'] as num?)?.toDouble() ?? 0.70,
      stability: (json['stability'] as num?)?.toDouble() ?? 0.60,
      style: (json['style'] as num?)?.toDouble() ?? 0.25,
      voiceEngine: json['voiceEngine'] as String? ?? AppConstants.voiceEngineNeural,
      emotionPreset: json['emotionPreset'] as String? ?? 'natural',
      elevenLabsApiKey: json['elevenLabsApiKey'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [
        pitch,
        rate,
        volume,
        languageCode,
        voiceName,
        voiceLocale,
        selectedVoiceId,
        emotion,
        stability,
        style,
        voiceEngine,
        emotionPreset,
        elevenLabsApiKey,
      ];
}
