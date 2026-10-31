import 'package:equatable/equatable.dart';
import '../../../settings/data/models/persona_model.dart';
import '../../../voice/data/models/voice_configuration.dart';
import '../../../voice/data/preset_voices.dart';

/// Represents a distinct AI Persona Character with its own identity, personality,
/// prompt instructions, dedicated voice binding, and age suitability.
class AICharacterModel extends Equatable {
  final String id;
  final String name;
  final String avatar; // Emoji or asset symbol
  final String category; // 'friends' | 'education' | 'experts' | 'entertainment' | 'emotional_support'
  final String shortDescription;
  final String detailedBio;
  final String sampleGreeting;
  final String systemPrompt;
  final VoiceConfiguration voiceConfig;
  final String speakingStyle;
  final String gender; // 'female' | 'male' | 'neutral'
  final String ageSuitability; // 'all' | 'kids' | 'teens' | 'adults'
  final List<String> tags;
  final bool isFeatured;
  final bool isFavorite;
  final bool isCustom; // True if user-created or user-customized
  final String? baseCharacterId; // Null if original or from scratch; non-null if customized from base
  final int chatCount;
  final double rating;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Compatibility getter for legacy callers
  String get voiceId => voiceConfig.voiceId;

  const AICharacterModel({
    required this.id,
    required this.name,
    required this.avatar,
    required this.category,
    required this.shortDescription,
    required this.detailedBio,
    required this.sampleGreeting,
    required this.systemPrompt,
    required this.voiceConfig,
    this.speakingStyle = 'Thân thiện, gần gũi',
    this.gender = 'female',
    this.ageSuitability = 'all',
    this.tags = const [],
    this.isFeatured = false,
    this.isFavorite = false,
    this.isCustom = false,
    this.baseCharacterId,
    this.chatCount = 120,
    this.rating = 4.9,
    this.createdAt,
    this.updatedAt,
  });

  AICharacterModel copyWith({
    String? id,
    String? name,
    String? avatar,
    String? category,
    String? shortDescription,
    String? detailedBio,
    String? sampleGreeting,
    String? systemPrompt,
    VoiceConfiguration? voiceConfig,
    String? speakingStyle,
    String? gender,
    String? ageSuitability,
    List<String>? tags,
    bool? isFeatured,
    bool? isFavorite,
    bool? isCustom,
    String? baseCharacterId,
    int? chatCount,
    double? rating,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AICharacterModel(
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      category: category ?? this.category,
      shortDescription: shortDescription ?? this.shortDescription,
      detailedBio: detailedBio ?? this.detailedBio,
      sampleGreeting: sampleGreeting ?? this.sampleGreeting,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      voiceConfig: voiceConfig ?? this.voiceConfig,
      speakingStyle: speakingStyle ?? this.speakingStyle,
      gender: gender ?? this.gender,
      ageSuitability: ageSuitability ?? this.ageSuitability,
      tags: tags ?? this.tags,
      isFeatured: isFeatured ?? this.isFeatured,
      isFavorite: isFavorite ?? this.isFavorite,
      isCustom: isCustom ?? this.isCustom,
      baseCharacterId: baseCharacterId ?? this.baseCharacterId,
      chatCount: chatCount ?? this.chatCount,
      rating: rating ?? this.rating,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatar': avatar,
      'category': category,
      'shortDescription': shortDescription,
      'detailedBio': detailedBio,
      'sampleGreeting': sampleGreeting,
      'systemPrompt': systemPrompt,
      'voiceConfig': voiceConfig.toJson(),
      'voiceId': voiceConfig.voiceId, // Legacy backward compatibility
      'speakingStyle': speakingStyle,
      'gender': gender,
      'ageSuitability': ageSuitability,
      'tags': tags,
      'isFeatured': isFeatured,
      'isFavorite': isFavorite,
      'isCustom': isCustom,
      'baseCharacterId': baseCharacterId,
      'chatCount': chatCount,
      'rating': rating,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory AICharacterModel.fromJson(Map<String, dynamic> json) {
    final rawGender = json['gender'] as String? ?? 'female';

    // Resolve VoiceConfiguration with fallback to preset voice by ID or gender
    VoiceConfiguration resolvedVoiceConfig;
    if (json['voiceConfig'] != null && json['voiceConfig'] is Map<String, dynamic>) {
      resolvedVoiceConfig = VoiceConfiguration.fromJson(json['voiceConfig'] as Map<String, dynamic>);
    } else {
      final legacyVoiceId = json['voiceId'] as String? ?? '';
      resolvedVoiceConfig = PresetVoices.getVoiceConfigForId(
        legacyVoiceId,
        fallbackGender: rawGender,
      );
    }

    return AICharacterModel(
      id: json['id'] as String,
      name: json['name'] as String,
      avatar: json['avatar'] as String? ?? '✨',
      category: json['category'] as String? ?? 'friends',
      shortDescription: json['shortDescription'] as String? ?? '',
      detailedBio: json['detailedBio'] as String? ?? '',
      sampleGreeting: json['sampleGreeting'] as String? ?? 'Xin chào bạn! Mình có thể hỗ trợ gì cho bạn hôm nay?',
      systemPrompt: json['systemPrompt'] as String,
      voiceConfig: resolvedVoiceConfig,
      speakingStyle: json['speakingStyle'] as String? ?? 'Thân thiện, gần gũi',
      gender: rawGender,
      ageSuitability: json['ageSuitability'] as String? ?? 'all',
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      isFeatured: json['isFeatured'] as bool? ?? false,
      isFavorite: json['isFavorite'] as bool? ?? false,
      isCustom: json['isCustom'] as bool? ?? false,
      baseCharacterId: json['baseCharacterId'] as String?,
      chatCount: json['chatCount'] as int? ?? 120,
      rating: (json['rating'] as num?)?.toDouble() ?? 4.9,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'] as String) : null,
    );
  }

  String get categoryLabel {
    switch (category) {
      case 'education':
        return 'Học tập & Kiến thức';
      case 'experts':
        return 'Chuyên gia';
      case 'entertainment':
        return 'Giải trí & Nhập vai';
      case 'emotional_support':
        return 'Tâm sự & Chữa lành';
      case 'friends':
      default:
        return 'Bạn bè & Giao tiếp';
    }
  }

  /// Converts this character into a PersonaModel for voice and LLM processing.
  PersonaModel toPersonaModel({String promptAddon = ''}) {
    return PersonaModel(
      id: id,
      name: name,
      description: shortDescription,
      avatarEmoji: avatar,
      systemPrompt: systemPrompt + (promptAddon.isNotEmpty ? '\n$promptAddon' : ''),
      defaultPitch: voiceConfig.pitch,
      defaultRate: voiceConfig.speed,
      languageCode: voiceConfig.languageCode,
      isBuiltIn: !isCustom,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        avatar,
        category,
        shortDescription,
        detailedBio,
        sampleGreeting,
        systemPrompt,
        voiceConfig,
        speakingStyle,
        gender,
        ageSuitability,
        tags,
        isFeatured,
        isFavorite,
        isCustom,
        baseCharacterId,
        chatCount,
        rating,
        createdAt,
        updatedAt,
      ];
}
