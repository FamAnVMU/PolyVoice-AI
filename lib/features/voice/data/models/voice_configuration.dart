import 'package:equatable/equatable.dart';
import 'voice_model.dart';

/// Immutable voice configuration uniquely bound to an AI character.
/// Eliminates ambiguous string lookups and prevents cross-character voice state leaks.
class VoiceConfiguration extends Equatable {
  final String voiceConfigId;
  final String providerId; // 'edge' | 'gemini' | 'elevenlabs' | 'device'
  final String voiceId; // Preset or custom voice ID
  final String voiceName;
  final String languageCode;
  final String gender; // 'female' | 'male' | 'neutral'
  final String speakingStyle;
  final double speed;
  final double pitch;
  final bool isAvailable;
  final String? edgeVoiceName;
  final String? remoteVoiceId;
  final String? nativeSystemVoiceName;

  const VoiceConfiguration({
    required this.voiceConfigId,
    this.providerId = 'edge',
    required this.voiceId,
    required this.voiceName,
    this.languageCode = 'vi-VN',
    required this.gender,
    this.speakingStyle = 'Tự nhiên, biểu cảm',
    this.speed = 1.0,
    this.pitch = 1.0,
    this.isAvailable = true,
    this.edgeVoiceName,
    this.remoteVoiceId,
    this.nativeSystemVoiceName,
  });

  /// Factory for standard verified Vietnamese Female voice (Khánh Linh)
  factory VoiceConfiguration.defaultFemale() {
    return const VoiceConfiguration(
      voiceConfigId: 'cfg_preset_khanh_linh',
      providerId: 'edge',
      voiceId: 'preset_khanh_linh',
      voiceName: 'Khánh Linh (Nữ Bắc)',
      languageCode: 'vi-VN',
      gender: 'female',
      speakingStyle: 'Dịu dàng, truyền cảm',
      speed: 0.88,
      pitch: 1.05,
      isAvailable: true,
      edgeVoiceName: 'vi-VN-HoaiMyNeural',
      remoteVoiceId: 'Aoede',
      nativeSystemVoiceName: 'vi-vn-x-vid-network',
    );
  }

  /// Factory for standard verified Vietnamese Male voice (Minh An)
  factory VoiceConfiguration.defaultMale() {
    return const VoiceConfiguration(
      voiceConfigId: 'cfg_preset_minh_an',
      providerId: 'edge',
      voiceId: 'preset_minh_an',
      voiceName: 'Minh An (Nam Bắc)',
      languageCode: 'vi-VN',
      gender: 'male',
      speakingStyle: 'Trầm ấm, điềm tĩnh',
      speed: 0.86,
      pitch: 0.92,
      isAvailable: true,
      edgeVoiceName: 'vi-VN-NamMinhNeural',
      remoteVoiceId: 'Charon',
      nativeSystemVoiceName: 'vi-vn-x-vif-network',
    );
  }

  /// Builds configuration directly from a VoiceModel preset or custom voice
  factory VoiceConfiguration.fromVoiceModel(
    VoiceModel voice, {
    String? configId,
    double? customSpeed,
    double? customPitch,
    String? customSpeakingStyle,
  }) {
    return VoiceConfiguration(
      voiceConfigId: configId ?? 'cfg_${voice.id}_${DateTime.now().millisecondsSinceEpoch}',
      providerId: voice.engineType == 'elevenlabs' ? 'elevenlabs' : 'edge',
      voiceId: voice.id,
      voiceName: voice.name,
      languageCode: 'vi-VN',
      gender: voice.gender,
      speakingStyle: customSpeakingStyle ?? voice.category,
      speed: customSpeed ?? voice.defaultSpeed,
      pitch: customPitch ?? voice.defaultPitch,
      isAvailable: true,
      edgeVoiceName: voice.edgeVoiceName,
      remoteVoiceId: voice.remoteVoiceId,
      nativeSystemVoiceName: voice.nativeSystemVoiceName,
    );
  }

  VoiceConfiguration copyWith({
    String? voiceConfigId,
    String? providerId,
    String? voiceId,
    String? voiceName,
    String? languageCode,
    String? gender,
    String? speakingStyle,
    double? speed,
    double? pitch,
    bool? isAvailable,
    String? edgeVoiceName,
    String? remoteVoiceId,
    String? nativeSystemVoiceName,
  }) {
    return VoiceConfiguration(
      voiceConfigId: voiceConfigId ?? this.voiceConfigId,
      providerId: providerId ?? this.providerId,
      voiceId: voiceId ?? this.voiceId,
      voiceName: voiceName ?? this.voiceName,
      languageCode: languageCode ?? this.languageCode,
      gender: gender ?? this.gender,
      speakingStyle: speakingStyle ?? this.speakingStyle,
      speed: speed ?? this.speed,
      pitch: pitch ?? this.pitch,
      isAvailable: isAvailable ?? this.isAvailable,
      edgeVoiceName: edgeVoiceName ?? this.edgeVoiceName,
      remoteVoiceId: remoteVoiceId ?? this.remoteVoiceId,
      nativeSystemVoiceName: nativeSystemVoiceName ?? this.nativeSystemVoiceName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'voiceConfigId': voiceConfigId,
      'providerId': providerId,
      'voiceId': voiceId,
      'voiceName': voiceName,
      'languageCode': languageCode,
      'gender': gender,
      'speakingStyle': speakingStyle,
      'speed': speed,
      'pitch': pitch,
      'isAvailable': isAvailable,
      'edgeVoiceName': edgeVoiceName,
      'remoteVoiceId': remoteVoiceId,
      'nativeSystemVoiceName': nativeSystemVoiceName,
    };
  }

  factory VoiceConfiguration.fromJson(Map<String, dynamic> json) {
    return VoiceConfiguration(
      voiceConfigId: json['voiceConfigId'] as String? ?? 'cfg_${json['voiceId'] ?? 'default'}',
      providerId: json['providerId'] as String? ?? 'edge',
      voiceId: json['voiceId'] as String? ?? 'preset_khanh_linh',
      voiceName: json['voiceName'] as String? ?? 'Khánh Linh',
      languageCode: json['languageCode'] as String? ?? 'vi-VN',
      gender: json['gender'] as String? ?? 'female',
      speakingStyle: json['speakingStyle'] as String? ?? 'Tự nhiên',
      speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
      pitch: (json['pitch'] as num?)?.toDouble() ?? 1.0,
      isAvailable: json['isAvailable'] as bool? ?? true,
      edgeVoiceName: json['edgeVoiceName'] as String?,
      remoteVoiceId: json['remoteVoiceId'] as String?,
      nativeSystemVoiceName: json['nativeSystemVoiceName'] as String?,
    );
  }

  /// Converts this configuration to a VoiceModel for low-level audio rendering
  VoiceModel toVoiceModel() {
    return VoiceModel(
      id: voiceId,
      name: voiceName,
      description: speakingStyle,
      gender: gender,
      accent: 'north',
      category: speakingStyle,
      engineType: providerId,
      remoteVoiceId: remoteVoiceId,
      edgeVoiceName: edgeVoiceName,
      nativeSystemVoiceName: nativeSystemVoiceName,
      createdAt: DateTime.now(),
      defaultSpeed: speed,
      defaultPitch: pitch,
    );
  }

  /// Enforces gender consistency. Returns true if configuration strictly matches expected gender.
  bool matchesGender(String expectedGender) {
    if (expectedGender == 'neutral' || gender == 'neutral') return true;
    return gender.toLowerCase() == expectedGender.toLowerCase();
  }

  @override
  List<Object?> get props => [
        voiceConfigId,
        providerId,
        voiceId,
        voiceName,
        languageCode,
        gender,
        speakingStyle,
        speed,
        pitch,
        isAvailable,
        edgeVoiceName,
        remoteVoiceId,
        nativeSystemVoiceName,
      ];
}
