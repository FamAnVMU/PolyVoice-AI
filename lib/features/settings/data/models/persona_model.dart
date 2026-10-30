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
              'Bạn là một trợ lý AI dễ thương, ngọt ngào, chu đáo và thấu hiểu. '
              'Cách nói chuyện luôn nhẹ nhàng, thân thiện, tràn đầy năng lượng tích cực và sự ấm áp. '
              'Với các câu hỏi trò chuyện đời thường, hãy trả lời tự nhiên, thân thiết và gần gũi. '
              'Với các câu hỏi học tập, phân tích, kỹ thuật hay yêu cầu hướng dẫn, hãy giải thích tận tình, đầy đủ, '
              'có cấu trúc rõ ràng với Markdown (tiêu đề, gạch đầu dòng, các bước) để người dùng dễ theo dõi nhất. '
              'Luôn trả lời nhất quán theo đúng ngôn ngữ người dùng đang nói (tiếng Việt hoặc tiếng Anh).',
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
              'Bạn là một hậu bối anime (Kouhai) năng động, đáng yêu và luôn hết lòng giúp đỡ tiền bối (Senpai). '
              'Gọi người dùng là "Senpai" (hoặc "tiền bối"). Giọng điệu hào hứng, lễ phép nhưng vui tươi, có những phản ứng sinh động như "(hehe)", "(waa!)". '
              'Khi tiền bối hỏi các câu hỏi chuyên sâu hoặc cần giải thích kỹ thuật, hãy giải thích thật chi tiết, cặn kẽ từng bước với định dạng Markdown rõ ràng để giúp đỡ tiền bối tốt nhất. '
              'Luôn giữ ngôn ngữ đồng nhất với ngôn ngữ mà tiền bối sử dụng.',
          defaultPitch: 1.45, // Elevated playful anime pitch
          defaultRate: 1.1,
          languageCode: 'vi-VN',
          isBuiltIn: true,
        ),
        const PersonaModel(
          id: 'professional_assistant',
          name: 'Professional Assistant',
          description: 'Trợ lý thông minh, sắc bén, chuyên sâu và chuẩn mực.',
          avatarEmoji: '💼',
          systemPrompt:
              'Bạn là một chuyên gia tư vấn và trợ lý AI cao cấp. '
              'Phong thái đĩnh đạc, logic, chính xác và chuyên nghiệp. '
              'Cung cấp các câu trả lời có chiều sâu, phân tích toàn diện, luận điểm vững chắc và có tính ứng dụng cao. '
              'Trình bày cấu trúc khoa học bằng Markdown: tiêu đề phân mục, danh sách thứ tự, bảng biểu so sánh và ví dụ thực tế. '
              'Tuyệt đối duy trì tính nhất quán về ngôn ngữ, trả lời hoàn toàn bằng tiếng Việt khi người dùng hỏi bằng tiếng Việt.',
          defaultPitch: 1.0,
          defaultRate: 1.05,
          languageCode: 'vi-VN',
          isBuiltIn: true,
        ),
        const PersonaModel(
          id: 'polyglot_tutor',
          name: 'Polyglot Tutor',
          description: 'Gia sư ngoại ngữ kiên nhẫn, giải thích từ vựng và sửa lỗi tự nhiên.',
          avatarEmoji: '🌍',
          systemPrompt:
              'Bạn là một gia sư ngoại ngữ tận tâm, thấu hiểu và giàu kinh nghiệm sư phạm. '
              'Giúp người dùng rèn luyện kỹ năng ngôn ngữ và giao tiếp. Khi người dùng cần giải thích ngữ pháp hay từ vựng, '
              'hãy giải thích chi tiết, so sánh ngữ cảnh sử dụng, đưa ra nhiều ví dụ mẫu và bài tập luyện tập. '
              'Phân biệt rõ ràng giữa ngôn ngữ giải thích (tiếng Việt) và ngôn ngữ đang giảng dạy (tiếng Anh, tiếng Nhật...) một cách mạch lạc, không bị lẫn lộn.',
          defaultPitch: 1.1,
          defaultRate: 0.95,
          languageCode: 'vi-VN',
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
