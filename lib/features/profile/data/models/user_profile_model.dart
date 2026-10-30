import 'package:equatable/equatable.dart';

/// User profile representing personalization preferences, age group, and communication style.
class UserProfileModel extends Equatable {
  final String name;
  final String avatarEmoji;
  final String ageGroup; // 'kids' (Dưới 12), 'teens' (12-22), 'adults' (23-55), 'seniors' (Trên 55)
  final String responseStyle; // 'detailed' (Chi tiết, sâu sắc), 'balanced' (Vừa phải), 'concise' (Súc tích)
  final String preferredLanguage; // 'vi' (Tiếng Việt), 'en' (English)
  final String preferredPronoun; // 'Bạn - Mình', 'Em - Anh/Chị', 'Thầy - Em', etc.
  final List<String> interests;
  final double fontSizeMultiplier;
  final bool preferVoice;
  final String customInstruction;

  const UserProfileModel({
    this.name = 'Bạn',
    this.avatarEmoji = '👤',
    this.ageGroup = 'adults',
    this.responseStyle = 'detailed',
    this.preferredLanguage = 'vi',
    this.preferredPronoun = 'Bạn - Mình',
    this.interests = const ['Công nghệ', 'Học tập', 'Đời sống', 'Sáng tạo'],
    this.fontSizeMultiplier = 1.0,
    this.preferVoice = false,
    this.customInstruction = '',
  });

  UserProfileModel copyWith({
    String? name,
    String? avatarEmoji,
    String? ageGroup,
    String? responseStyle,
    String? preferredLanguage,
    String? preferredPronoun,
    List<String>? interests,
    double? fontSizeMultiplier,
    bool? preferVoice,
    String? customInstruction,
  }) {
    return UserProfileModel(
      name: name ?? this.name,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      ageGroup: ageGroup ?? this.ageGroup,
      responseStyle: responseStyle ?? this.responseStyle,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      preferredPronoun: preferredPronoun ?? this.preferredPronoun,
      interests: interests ?? this.interests,
      fontSizeMultiplier: fontSizeMultiplier ?? this.fontSizeMultiplier,
      preferVoice: preferVoice ?? this.preferVoice,
      customInstruction: customInstruction ?? this.customInstruction,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'avatarEmoji': avatarEmoji,
      'ageGroup': ageGroup,
      'responseStyle': responseStyle,
      'preferredLanguage': preferredLanguage,
      'preferredPronoun': preferredPronoun,
      'interests': interests,
      'fontSizeMultiplier': fontSizeMultiplier,
      'preferVoice': preferVoice,
      'customInstruction': customInstruction,
    };
  }

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      name: json['name'] as String? ?? 'Bạn',
      avatarEmoji: json['avatarEmoji'] as String? ?? '👤',
      ageGroup: json['ageGroup'] as String? ?? 'adults',
      responseStyle: json['responseStyle'] as String? ?? 'detailed',
      preferredLanguage: json['preferredLanguage'] as String? ?? 'vi',
      preferredPronoun: json['preferredPronoun'] as String? ?? 'Bạn - Mình',
      interests: (json['interests'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const ['Công nghệ', 'Học tập', 'Đời sống', 'Sáng tạo'],
      fontSizeMultiplier: (json['fontSizeMultiplier'] as num?)?.toDouble() ?? 1.0,
      preferVoice: json['preferVoice'] as bool? ?? false,
      customInstruction: json['customInstruction'] as String? ?? '',
    );
  }

  String get ageGroupLabel {
    switch (ageGroup) {
      case 'kids':
        return 'Thiếu nhi (Dưới 12 tuổi)';
      case 'teens':
        return 'Học sinh & Sinh viên (12 - 22 tuổi)';
      case 'seniors':
        return 'Người lớn tuổi (Trên 55 tuổi)';
      case 'adults':
      default:
        return 'Người trưởng thành (Đi làm / Nghiên cứu)';
    }
  }

  String get responseStyleLabel {
    switch (responseStyle) {
      case 'concise':
        return 'Súc tích, nhanh gọn';
      case 'balanced':
        return 'Cân bằng, vừa đủ';
      case 'detailed':
      default:
        return 'Phân tích chi tiết, có chiều sâu';
    }
  }

  /// Builds prompt personalization instructions injected into the AI system prompt.
  String buildSystemPromptAddon() {
    final buffer = StringBuffer();
    buffer.writeln('\n[Thông tin hồ sơ và tùy chỉnh cá nhân của người dùng]');

    // Age group guideline
    switch (ageGroup) {
      case 'kids':
        buffer.writeln('- Đối tượng người dùng: Trẻ em (dưới 12 tuổi). Hãy dùng từ ngữ trong sáng, thân thiện, ấm áp, giải thích bằng các ví dụ trực quan dễ hiểu; tuyệt đối không dùng từ ngữ người lớn, bạo lực hay thuật ngữ quá phức tạp.');
        break;
      case 'teens':
        buffer.writeln('- Đối tượng người dùng: Học sinh / sinh viên (12 - 22 tuổi). Phong cách trao đổi trẻ trung, năng động, khuyến khích tư duy phản biện, hỗ trợ phương pháp học tập thông minh.');
        break;
      case 'seniors':
        buffer.writeln('- Đối tượng người dùng: Người lớn tuổi (trên 55 tuổi). Giọng điệu kính trọng, từ tốn, ấm áp, kiên nhẫn giải thích từng bước rõ ràng, ngắn gọn và dễ nắm bắt.');
        break;
      case 'adults':
      default:
        buffer.writeln('- Đối tượng người dùng: Người trưởng thành đi làm / nghiên cứu. Cung cấp thông tin có chiều sâu, lập luận chặt chẽ, thực tế và hiệu quả.');
        break;
    }

    // Response style
    switch (responseStyle) {
      case 'concise':
        buffer.writeln('- Phong cách trả lời: Súc tích, nhanh gọn, đi thẳng vào trọng tâm vấn đề.');
        break;
      case 'balanced':
        buffer.writeln('- Phong cách trả lời: Cân bằng, cô đọng nhưng đủ ý.');
        break;
      case 'detailed':
      default:
        buffer.writeln('- Phong cách trả lời: Đầy đủ, chi tiết, phân tích đa chiều và trình bày khoa học với Markdown.');
        break;
    }

    if (preferredPronoun.isNotEmpty && preferredPronoun != 'Mặc định') {
      buffer.writeln('- Cách xưng hô ưu tiên: $preferredPronoun.');
    }

    if (customInstruction.trim().isNotEmpty) {
      buffer.writeln('- Chỉ dẫn riêng của người dùng: ${customInstruction.trim()}');
    }

    return buffer.toString();
  }

  @override
  List<Object?> get props => [
        name,
        avatarEmoji,
        ageGroup,
        responseStyle,
        preferredLanguage,
        preferredPronoun,
        interests,
        fontSizeMultiplier,
        preferVoice,
        customInstruction,
      ];
}
