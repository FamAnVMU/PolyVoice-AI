import 'package:equatable/equatable.dart';

class VoiceModel extends Equatable {
  final String id;
  final String name;
  final String description;
  final String gender; // 'female' | 'male' | 'neutral'
  final String accent; // 'north' (Bắc) | 'south' (Nam) | 'central' (Trung) | 'intl' (Quốc tế)
  final String category; // 'gentle', 'warm', 'dynamic', 'professional', 'storytelling', 'young', 'mature', 'custom'
  final String engineType; // 'neural', 'gemini', 'elevenlabs', 'device', 'custom'
  final String? remoteVoiceId; // Voice ID on remote cloud service (e.g. Aoede, Kore, Puck, Charon, Fenrir or ElevenLabs ID)
  final String? nativeSystemVoiceName; // Android TTS voice name (e.g. vi-vn-x-vid-network, vi-vn-x-vie-network, vi-vn-x-vif-network)
  final String? referenceAudioPath; // Local path to audio/video reference file
  final bool isCustom;
  final DateTime createdAt;
  final double defaultSpeed;
  final double defaultPitch;
  final String emotionPreset; // 'cheerful', 'calm', 'empathetic', 'serious', 'excited', 'natural', 'explanatory', 'storytelling'
  final String sampleText;

  const VoiceModel({
    required this.id,
    required this.name,
    required this.description,
    required this.gender,
    required this.accent,
    required this.category,
    this.engineType = 'neural',
    this.remoteVoiceId,
    this.nativeSystemVoiceName,
    this.referenceAudioPath,
    this.isCustom = false,
    required this.createdAt,
    this.defaultSpeed = 0.88,
    this.defaultPitch = 1.0,
    this.emotionPreset = 'natural',
    this.sampleText = 'Xin chào! Mình rất vui được trò chuyện và hỗ trợ bạn hôm nay.',
  });

  VoiceModel copyWith({
    String? id,
    String? name,
    String? description,
    String? gender,
    String? accent,
    String? category,
    String? engineType,
    String? remoteVoiceId,
    String? nativeSystemVoiceName,
    String? referenceAudioPath,
    bool? isCustom,
    DateTime? createdAt,
    double? defaultSpeed,
    double? defaultPitch,
    String? emotionPreset,
    String? sampleText,
  }) {
    return VoiceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      gender: gender ?? this.gender,
      accent: accent ?? this.accent,
      category: category ?? this.category,
      engineType: engineType ?? this.engineType,
      remoteVoiceId: remoteVoiceId ?? this.remoteVoiceId,
      nativeSystemVoiceName: nativeSystemVoiceName ?? this.nativeSystemVoiceName,
      referenceAudioPath: referenceAudioPath ?? this.referenceAudioPath,
      isCustom: isCustom ?? this.isCustom,
      createdAt: createdAt ?? this.createdAt,
      defaultSpeed: defaultSpeed ?? this.defaultSpeed,
      defaultPitch: defaultPitch ?? this.defaultPitch,
      emotionPreset: emotionPreset ?? this.emotionPreset,
      sampleText: sampleText ?? this.sampleText,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'gender': gender,
      'accent': accent,
      'category': category,
      'engineType': engineType,
      'remoteVoiceId': remoteVoiceId,
      'nativeSystemVoiceName': nativeSystemVoiceName,
      'referenceAudioPath': referenceAudioPath,
      'isCustom': isCustom,
      'createdAt': createdAt.toIso8601String(),
      'defaultSpeed': defaultSpeed,
      'defaultPitch': defaultPitch,
      'emotionPreset': emotionPreset,
      'sampleText': sampleText,
    };
  }

  factory VoiceModel.fromJson(Map<String, dynamic> json) {
    return VoiceModel(
      id: json['id'] as String? ?? 'voice_${DateTime.now().millisecondsSinceEpoch}',
      name: json['name'] as String? ?? 'Giọng tùy chỉnh',
      description: json['description'] as String? ?? 'Giọng nói cá nhân được tạo từ dữ liệu tham chiếu',
      gender: json['gender'] as String? ?? 'neutral',
      accent: json['accent'] as String? ?? 'north',
      category: json['category'] as String? ?? 'custom',
      engineType: json['engineType'] as String? ?? 'custom',
      remoteVoiceId: json['remoteVoiceId'] as String?,
      nativeSystemVoiceName: json['nativeSystemVoiceName'] as String?,
      referenceAudioPath: json['referenceAudioPath'] as String?,
      isCustom: json['isCustom'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      defaultSpeed: (json['defaultSpeed'] as num?)?.toDouble() ?? 0.88,
      defaultPitch: (json['defaultPitch'] as num?)?.toDouble() ?? 1.0,
      emotionPreset: json['emotionPreset'] as String? ?? 'natural',
      sampleText: json['sampleText'] as String? ??
          'Xin chào! Đây là giọng nói cá nhân của mình, rất vui được trò chuyện cùng bạn.',
    );
  }

  String get genderLabel {
    switch (gender) {
      case 'female':
        return 'Nữ';
      case 'male':
        return 'Nam';
      default:
        return 'Trung tính';
    }
  }

  String get accentLabel {
    switch (accent) {
      case 'north':
        return 'Giọng Bắc (Hà Nội)';
      case 'south':
        return 'Giọng Nam (Sài Gòn)';
      case 'central':
        return 'Giọng Miền Trung';
      default:
        return 'Quốc tế / Tiếng Anh';
    }
  }

  String get categoryLabel {
    switch (category) {
      case 'gentle':
        return 'Dịu dàng';
      case 'warm':
        return 'Trầm ấm';
      case 'dynamic':
        return 'Năng động';
      case 'professional':
        return 'Chuyên nghiệp';
      case 'storytelling':
        return 'Kể chuyện';
      case 'young':
        return 'Trẻ trung';
      case 'mature':
        return 'Trưởng thành';
      case 'custom':
        return 'Giọng cá nhân';
      default:
        return 'Tự nhiên';
    }
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        gender,
        accent,
        category,
        engineType,
        remoteVoiceId,
        nativeSystemVoiceName,
        referenceAudioPath,
        isCustom,
        createdAt,
        defaultSpeed,
        defaultPitch,
        emotionPreset,
        sampleText,
      ];
}
