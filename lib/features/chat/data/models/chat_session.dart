import 'package:equatable/equatable.dart';
import 'chat_message.dart';

class ChatSession extends Equatable {
  final String id;
  final String title;
  final String characterId;
  final String characterName;
  final String characterAvatar;
  final String systemPrompt;
  final String voiceId;
  final bool isPinned;
  final bool isArchived;
  final List<String> memoryNotes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatMessage> messages;

  const ChatSession({
    required this.id,
    required this.title,
    this.characterId = 'char_khanh_linh',
    this.characterName = 'Khánh Linh',
    this.characterAvatar = '🌸',
    this.systemPrompt = '',
    this.voiceId = 'preset_khanh_linh',
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
    String? characterName,
    String? characterAvatar,
    String? systemPrompt,
    String? voiceId,
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
      characterName: characterName ?? this.characterName,
      characterAvatar: characterAvatar ?? this.characterAvatar,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      voiceId: voiceId ?? this.voiceId,
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
      'characterName': characterName,
      'characterAvatar': characterAvatar,
      'systemPrompt': systemPrompt,
      'voiceId': voiceId,
      'isPinned': isPinned,
      'isArchived': isArchived,
      'memoryNotes': memoryNotes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'messages': messages.map((m) => m.toJson()).toList(),
    };
  }

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Cuộc trò chuyện',
      // Automatic migration: Preserve old sessions and assign default character without data loss
      characterId: json['characterId'] as String? ?? 'char_khanh_linh',
      characterName: json['characterName'] as String? ?? 'Khánh Linh',
      characterAvatar: json['characterAvatar'] as String? ?? '🌸',
      systemPrompt: json['systemPrompt'] as String? ?? '',
      voiceId: json['voiceId'] as String? ?? 'preset_khanh_linh',
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
        characterName,
        characterAvatar,
        systemPrompt,
        voiceId,
        isPinned,
        isArchived,
        memoryNotes,
        createdAt,
        updatedAt,
        messages,
      ];
}
