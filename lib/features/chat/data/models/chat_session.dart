import 'package:equatable/equatable.dart';
import '../../../character/data/character_library.dart';
import '../../../voice/data/models/voice_configuration.dart';
import '../../../voice/data/preset_voices.dart';
import 'chat_message.dart';

class ChatSession extends Equatable {
  final String id;
  final String title;
  final String characterId;
  final String? customCharacterId;
  final String characterName;
  final String characterAvatar;
  final String systemPrompt;
  final VoiceConfiguration voiceConfig;
  final bool isPinned;
  final bool isArchived;
  final List<String> memoryNotes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatMessage> messages;

  // Compatibility getter
  String get voiceId => voiceConfig.voiceId;

  const ChatSession({
    required this.id,
    required this.title,
    this.characterId = 'char_khanh_linh',
    this.customCharacterId,
    this.characterName = 'Khánh Linh',
    this.characterAvatar = '🌸',
    this.systemPrompt = '',
    required this.voiceConfig,
    this.isPinned = false,
    this.isArchived = false,
    this.memoryNotes = const [],
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
  });

  ChatSession copyWith({
    String? id,
    String? title,
    String? characterId,
    String? customCharacterId,
    String? characterName,
    String? characterAvatar,
    String? systemPrompt,
    VoiceConfiguration? voiceConfig,
    bool? isPinned,
    bool? isArchived,
    List<String>? memoryNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
  }) {
    return ChatSession(
      id: id ?? this.id,
      title: title ?? this.title,
      characterId: characterId ?? this.characterId,
      customCharacterId: customCharacterId ?? this.customCharacterId,
      characterName: characterName ?? this.characterName,
      characterAvatar: characterAvatar ?? this.characterAvatar,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      voiceConfig: voiceConfig ?? this.voiceConfig,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      memoryNotes: memoryNotes ?? this.memoryNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'characterId': characterId,
      'customCharacterId': customCharacterId,
      'characterName': characterName,
      'characterAvatar': characterAvatar,
      'systemPrompt': systemPrompt,
      'voiceConfig': voiceConfig.toJson(),
      'voiceId': voiceConfig.voiceId,
      'isPinned': isPinned,
      'isArchived': isArchived,
      'memoryNotes': memoryNotes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'messages': messages.map((m) => m.toJson()).toList(),
    };
  }

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    final charId = json['characterId'] as String? ?? 'char_khanh_linh';
    final charName = json['characterName'] as String? ?? 'Khánh Linh';
    final charAvatar = json['characterAvatar'] as String? ?? '🌸';

    // Automatic migration for voiceConfig
    VoiceConfiguration resolvedVoiceConfig;
    if (json['voiceConfig'] != null && json['voiceConfig'] is Map<String, dynamic>) {
      resolvedVoiceConfig = VoiceConfiguration.fromJson(json['voiceConfig'] as Map<String, dynamic>);
    } else {
      // Find character in CharacterLibrary to inherit exact voiceConfig
      final matchedChar = CharacterLibrary.findById(charId);
      final legacyVoiceId = json['voiceId'] as String? ?? matchedChar.voiceConfig.voiceId;
      resolvedVoiceConfig = PresetVoices.getVoiceConfigForId(
        legacyVoiceId,
        fallbackGender: matchedChar.gender,
      );
    }

    return ChatSession(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Cuộc trò chuyện',
      characterId: charId,
      customCharacterId: json['customCharacterId'] as String?,
      characterName: charName,
      characterAvatar: charAvatar,
      systemPrompt: json['systemPrompt'] as String? ?? '',
      voiceConfig: resolvedVoiceConfig,
      isPinned: json['isPinned'] as bool? ?? false,
      isArchived: json['isArchived'] as bool? ?? false,
      memoryNotes: (json['memoryNotes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now() : DateTime.now(),
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now() : DateTime.now(),
      messages: (json['messages'] as List<dynamic>?)
              ?.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        characterId,
        customCharacterId,
        characterName,
        characterAvatar,
        systemPrompt,
        voiceConfig,
        isPinned,
        isArchived,
        memoryNotes,
        createdAt,
        updatedAt,
        messages,
      ];
}
