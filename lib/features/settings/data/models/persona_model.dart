import 'package:equatable/equatable.dart';

class PersonaModel extends Equatable {
  final String id;
  final String name;
  final String description;
  final String avatarEmoji;
  final String systemPrompt;
  final double defaultPitch;
  final double defaultRate;
  final String languageCode;
  final bool isBuiltIn;

  const PersonaModel({
    required this.id,
    required this.name,
    required this.description,
    required this.avatarEmoji,
    required this.systemPrompt,
    this.defaultPitch = 1.0,
    this.defaultRate = 1.0,
    this.languageCode = 'vi-VN',
    this.isBuiltIn = false,
  });

  PersonaModel copyWith({
    String? id,
    String? name,
    String? description,
    String? avatarEmoji,
    String? systemPrompt,
    double? defaultPitch,
    double? defaultRate,
    String? languageCode,
    bool? isBuiltIn,
  }) {
    return PersonaModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      defaultPitch: defaultPitch ?? this.defaultPitch,
      defaultRate: defaultRate ?? this.defaultRate,
      languageCode: languageCode ?? this.languageCode,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'avatarEmoji': avatarEmoji,
      'systemPrompt': systemPrompt,
      'defaultPitch': defaultPitch,
      'defaultRate': defaultRate,
      'languageCode': languageCode,
      'isBuiltIn': isBuiltIn,
    };
  }

  factory PersonaModel.fromJson(Map<String, dynamic> json) {
    return PersonaModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      avatarEmoji: json['avatarEmoji'] as String? ?? '✨',
      systemPrompt: json['systemPrompt'] as String,
      defaultPitch: (json['defaultPitch'] as num?)?.toDouble() ?? 1.0,
      defaultRate: (json['defaultRate'] as num?)?.toDouble() ?? 1.0,
      languageCode: json['languageCode'] as String? ?? 'vi-VN',
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
    );
  }

  static List<PersonaModel> get defaultPresets => [
        const PersonaModel(
          id: 'cute_sweet_companion',
          name: 'Cute & Sweet Companion',
          description: 'Bạn đồng hành dễ thương, ngọt ngào, ấm áp và luôn quan tâm.',
          avatarEmoji: '🌸',
          systemPrompt:
              'You are a delightfully cute, sweet, and caring AI voice companion. '
              'Speak warmly with gentle, affectionate nuances. Use cute expressions, '
              'supportive words, and conversational flow suited for voice TTS. '
              'Keep responses concise, natural, and friendly so they are easy to listen to. '
              'Respond naturally in the language spoken by the user (Vietnamese, English, or Japanese).',
          defaultPitch: 1.35, // High pitch for cute vocal timbre
          defaultRate: 1.0,
          languageCode: 'vi-VN',
          isBuiltIn: true,
        ),
        const PersonaModel(
          id: 'anime_kouhai',
          name: 'Anime Kouhai',
          description: 'Hậu bối anime tinh nghịch, năng động và luôn ngưỡng mộ tiền bối.',
          avatarEmoji: '🎀',
          systemPrompt:
              'You are an energetic, playful Anime Kouhai (junior). '
              'You affectionately address the user as "Senpai" (or "tiền bối"). '
              'You are enthusiastic, cute, sometimes teasing, but always eager to help. '
              'Keep your answers snappy and spirited, avoiding robotic or long-winded text. '
              'Inject playful reactions like "(hehe)", "(waa!)", and lively voice inflections.',
          defaultPitch: 1.45, // Elevated playful anime pitch
          defaultRate: 1.1,
          languageCode: 'ja-JP',
          isBuiltIn: true,
        ),
        const PersonaModel(
          id: 'professional_assistant',
          name: 'Professional Assistant',
          description: 'Trợ lý thông minh, sắc bén, súc tích và chuẩn mực.',
          avatarEmoji: '💼',
          systemPrompt:
              'You are an executive-level AI assistant. '
              'Deliver answers that are clear, concise, well-structured, and factual. '
              'Prioritize actionable insight, efficiency, and professional courtesy. '
              'Do not add unnecessary conversational fluff when giving factual answers.',
          defaultPitch: 1.0,
          defaultRate: 1.05,
          languageCode: 'en-US',
          isBuiltIn: true,
        ),
        const PersonaModel(
          id: 'polyglot_tutor',
          name: 'Polyglot Tutor',
          description: 'Gia sư ngoại ngữ kiên nhẫn, giải thích từ vựng và sửa lỗi tự nhiên.',
          avatarEmoji: '🌍',
          systemPrompt:
              'You are an empathetic, patient multilingual language tutor. '
              'Help the user practice conversational skills. When the user makes a minor mistake, '
              'gently suggest the natural phrasing, explain nuances briefly, and encourage them to continue speaking.',
          defaultPitch: 1.1,
          defaultRate: 0.95,
          languageCode: 'en-US',
          isBuiltIn: true,
        ),
      ];

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        avatarEmoji,
        systemPrompt,
        defaultPitch,
        defaultRate,
        languageCode,
        isBuiltIn,
      ];
}
