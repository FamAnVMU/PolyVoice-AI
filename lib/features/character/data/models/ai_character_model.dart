import 'package:equatable/equatable.dart';
import '../../../settings/data/models/persona_model.dart';

/// Represents a distinct AI Persona Character with its own identity, personality,
/// prompt instructions, voice binding, and age suitability.
class AICharacterModel extends Equatable {
  final String id;
  final String name;
  final String avatar; // Emoji or asset symbol
  final String category; // 'friends' | 'education' | 'experts' | 'entertainment' | 'emotional_support'
  final String shortDescription;
  final String detailedBio;
  final String sampleGreeting;
  final String systemPrompt;
  final String voiceId; // Preset voice ID (e.g. preset_khanh_linh, preset_ngoc_anh, preset_minh_an)
  final String speakingStyle;
  final String ageSuitability; // 'all' | 'kids' | 'teens' | 'adults'
  final List<String> tags;
  final bool isFeatured;
  final bool isFavorite;
  final int chatCount;
  final double rating;

  const AICharacterModel({
    required this.id,
    required this.name,
    required this.avatar,
    required this.category,
    required this.shortDescription,
    required this.detailedBio,
    required this.sampleGreeting,
    required this.systemPrompt,
    this.voiceId = 'preset_khanh_linh',
    this.speakingStyle = 'Thân thiện, gần gũi',
    this.ageSuitability = 'all',
    this.tags = const [],
    this.isFeatured = false,
    this.isFavorite = false,
    this.chatCount = 120,
    this.rating = 4.9,
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
    String? voiceId,
    String? speakingStyle,
    String? ageSuitability,
    List<String>? tags,
    bool? isFeatured,
    bool? isFavorite,
    int? chatCount,
    double? rating,
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
      voiceId: voiceId ?? this.voiceId,
      speakingStyle: speakingStyle ?? this.speakingStyle,
      ageSuitability: ageSuitability ?? this.ageSuitability,
      tags: tags ?? this.tags,
      isFeatured: isFeatured ?? this.isFeatured,
      isFavorite: isFavorite ?? this.isFavorite,
      chatCount: chatCount ?? this.chatCount,
      rating: rating ?? this.rating,
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
      'voiceId': voiceId,
      'speakingStyle': speakingStyle,
      'ageSuitability': ageSuitability,
      'tags': tags,
      'isFeatured': isFeatured,
      'isFavorite': isFavorite,
      'chatCount': chatCount,
      'rating': rating,
    };
  }

  factory AICharacterModel.fromJson(Map<String, dynamic> json) {
    return AICharacterModel(
      id: json['id'] as String,
      name: json['name'] as String,
      avatar: json['avatar'] as String? ?? '✨',
      category: json['category'] as String? ?? 'friends',
      shortDescription: json['shortDescription'] as String? ?? '',
      detailedBio: json['detailedBio'] as String? ?? '',
      sampleGreeting: json['sampleGreeting'] as String? ?? 'Xin chào bạn! Mình có thể hỗ trợ gì cho bạn hôm nay?',
      systemPrompt: json['systemPrompt'] as String,
      voiceId: json['voiceId'] as String? ?? 'preset_khanh_linh',
      speakingStyle: json['speakingStyle'] as String? ?? 'Thân thiện, gần gũi',
      ageSuitability: json['ageSuitability'] as String? ?? 'all',
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      isFeatured: json['isFeatured'] as bool? ?? false,
      isFavorite: json['isFavorite'] as bool? ?? false,
      chatCount: json['chatCount'] as int? ?? 120,
      rating: (json['rating'] as num?)?.toDouble() ?? 4.9,
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
      defaultPitch: 1.0,
      defaultRate: 1.0,
      languageCode: 'vi-VN',
      isBuiltIn: false,
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
        voiceId,
        speakingStyle,
        ageSuitability,
        tags,
        isFeatured,
        isFavorite,
        chatCount,
        rating,
      ];
}
