import 'package:equatable/equatable.dart';

class VoiceConfigModel extends Equatable {
  final double pitch;
  final double rate;
  final double volume;
  final String languageCode;
  final String? voiceName;
  final String? voiceLocale;

  const VoiceConfigModel({
    this.pitch = 1.2,
    this.rate = 1.0,
    this.volume = 1.0,
    this.languageCode = 'vi-VN',
    this.voiceName,
    this.voiceLocale,
  });

  VoiceConfigModel copyWith({
    double? pitch,
    double? rate,
    double? volume,
    String? languageCode,
    String? voiceName,
    String? voiceLocale,
  }) {
    return VoiceConfigModel(
      pitch: pitch ?? this.pitch,
      rate: rate ?? this.rate,
      volume: volume ?? this.volume,
      languageCode: languageCode ?? this.languageCode,
      voiceName: voiceName ?? this.voiceName,
      voiceLocale: voiceLocale ?? this.voiceLocale,
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
    };
  }

  factory VoiceConfigModel.fromJson(Map<String, dynamic> json) {
    return VoiceConfigModel(
      pitch: (json['pitch'] as num?)?.toDouble() ?? 1.2,
      rate: (json['rate'] as num?)?.toDouble() ?? 1.0,
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
      languageCode: json['languageCode'] as String? ?? 'vi-VN',
      voiceName: json['voiceName'] as String?,
      voiceLocale: json['voiceLocale'] as String?,
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
      ];
}
