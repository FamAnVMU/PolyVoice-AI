import 'models/voice_model.dart';

class PresetVoices {
  static final List<VoiceModel> allPresets = [
    // 1. KHÁNH LINH (Nữ Bắc - Dịu dàng, truyền cảm, tâm sự)
    VoiceModel(
      id: 'preset_khanh_linh',
      name: 'Khánh Linh',
      description: 'Giọng nữ Hà Nội chuẩn: Dịu dàng, truyền cảm, ngữ điệu mềm mại tự nhiên. Thích hợp cho tâm sự, trò chuyện đời thường và chăm sóc.',
      gender: 'female',
      accent: 'north',
      category: 'gentle',
      engineType: 'neural',
      remoteVoiceId: 'Aoede', // Google Studio Neural: Melodic & Sweet Female
      edgeVoiceName: 'vi-VN-HoaiMyNeural', // Microsoft Edge Neural: Hoài My (Nữ VTV chuẩn)
      nativeSystemVoiceName: 'vi-vn-x-vid-network', // Android Google Neural Female North
      createdAt: DateTime(2026, 1, 1),
      defaultSpeed: 0.88,
      defaultPitch: 1.05,
      emotionPreset: 'empathetic',
      sampleText: 'Chào bạn! Hôm nay công việc của bạn có thuận lợi không? Mình luôn ở đây để lắng nghe và đồng hành cùng bạn nhé.',
    ),

    // 2. NGỌC ANH (Nữ Nam - Năng động, thanh thoát, hiện đại)
    VoiceModel(
      id: 'preset_ngoc_anh',
      name: 'Ngọc Anh',
      description: 'Giọng nữ Sài Gòn chuẩn: Tươi sáng, thanh thoát, rõ ràng, phong cách trợ lý công nghệ hiện đại. Thích hợp cho làm việc và giải đáp thông tin nhanh.',
      gender: 'female',
      accent: 'south',
      category: 'dynamic',
      engineType: 'neural',
      remoteVoiceId: 'Kore', // Google Studio Neural: Crisp & Clear Female
      edgeVoiceName: 'vi-VN-HoaiMyNeural', // Microsoft Edge Neural: Hoài My
      nativeSystemVoiceName: 'vi-vn-x-vie-network', // Android Google Neural Female South
      createdAt: DateTime(2026, 1, 1),
      defaultSpeed: 0.90,
      defaultPitch: 1.02,
      emotionPreset: 'cheerful',
      sampleText: 'Dạ em chào anh chị ạ! Lịch trình làm việc và các ghi chú quan trọng hôm nay đã sẵn sàng rồi nè. Mình bắt đầu ngay nha!',
    ),

    // 3. THẢO NHI (Nữ Trẻ - Trong trẻo, ngọt ngào, kể chuyện)
    VoiceModel(
      id: 'preset_thao_nhi',
      name: 'Thảo Nhi',
      description: 'Giọng nữ trẻ trong trẻo, ngọt ngào, ngân vang nhẹ, giàu biểu cảm. Rất tuyệt vời cho đọc truyện cổ tích, đọc thơ và nội dung sáng tạo.',
      gender: 'female',
      accent: 'north',
      category: 'storytelling',
      engineType: 'neural',
      remoteVoiceId: 'Aoede',
      edgeVoiceName: 'vi-VN-HoaiMyNeural',
      nativeSystemVoiceName: 'vi-vn-x-via-local', // Android Google Young Female
      createdAt: DateTime(2026, 1, 1),
      defaultSpeed: 0.84,
      defaultPitch: 1.15,
      emotionPreset: 'storytelling',
      sampleText: 'Ngày xửa ngày xưa, ở một ngôi làng nhỏ dưới chân núi mờ sương, có một dòng suối trong vắt róc rách chảy suốt bốn mùa... Thật là kỳ diệu!',
    ),

    // 4. HOÀNG YẾN (Nữ Trưởng thành - Sắc sảo, chuyên nghiệp)
    VoiceModel(
      id: 'preset_hoang_yen',
      name: 'Hoàng Yến',
      description: 'Giọng nữ trưởng thành đĩnh đạc, phát âm chuẩn xác từng chữ, phong thái biên tập viên truyền hình. Chuyên dùng cho tin tức, báo cáo kinh doanh.',
      gender: 'female',
      accent: 'north',
      category: 'professional',
      engineType: 'neural',
      remoteVoiceId: 'Kore',
      edgeVoiceName: 'vi-VN-HoaiMyNeural',
      nativeSystemVoiceName: 'vi-vn-x-vid-network',
      createdAt: DateTime(2026, 1, 1),
      defaultSpeed: 0.88,
      defaultPitch: 0.98,
      emotionPreset: 'explanatory',
      sampleText: 'Theo số liệu thống kê mới nhất, hiệu suất vận hành toàn diện đã tăng trưởng ba mươi phần trăm nhờ ứng dụng các giải pháp tự động hóa.',
    ),

    // 5. MINH AN (Nam Bắc - Trầm ấm, điềm tĩnh)
    VoiceModel(
      id: 'preset_minh_an',
      name: 'Minh An',
      description: 'Giọng nam Hà Nội trầm ấm, độ vang tốt, đĩnh đạc và đáng tin cậy. Dễ tiếp thu khi phân tích kiến thức sâu hoặc đọc sách nói.',
      gender: 'male',
      accent: 'north',
      category: 'warm',
      engineType: 'neural',
      remoteVoiceId: 'Charon', // Google Studio Neural: Deep & Resonant Male
      edgeVoiceName: 'vi-VN-NamMinhNeural', // Microsoft Edge Neural: Nam Minh (Nam đài truyền hình)
      nativeSystemVoiceName: 'vi-vn-x-vif-network', // Android Google Neural Male North
      createdAt: DateTime(2026, 1, 1),
      defaultSpeed: 0.86,
      defaultPitch: 0.92,
      emotionPreset: 'calm',
      sampleText: 'Xin chào. Trí tuệ nhân tạo đang thay đổi cách chúng ta làm việc mỗi ngày. Tôi rất sẵn lòng cùng bạn phân tích chuyên sâu vấn đề này.',
    ),

    // 6. GIA HUY (Nam Nam - Năng động, thân thiện)
    VoiceModel(
      id: 'preset_gia_huy',
      name: 'Gia Huy',
      description: 'Giọng nam miền Nam tươi vui, trẻ trung, linh hoạt, tạo cảm giác thân thiết như một người bạn thân cùng bàn.',
      gender: 'male',
      accent: 'south',
      category: 'young',
      engineType: 'neural',
      remoteVoiceId: 'Puck', // Google Studio Neural: Upbeat & Lively Male
      edgeVoiceName: 'vi-VN-NamMinhNeural',
      nativeSystemVoiceName: 'vi-vn-x-vic-network', // Android Google Neural Male South
      createdAt: DateTime(2026, 1, 1),
      defaultSpeed: 0.92,
      defaultPitch: 1.00,
      emotionPreset: 'excited',
      sampleText: 'Ê bạn ơi! Hôm nay có chuyện gì thú vị không? Cứ thoải mái tâm sự với mình nha, đừng để deadline làm bạn căng thẳng!',
    ),

    // 7. QUỐC BẢO (Nam Miền Trung - Chân thành, sâu lắng)
    VoiceModel(
      id: 'preset_quoc_bao',
      name: 'Quốc Bảo',
      description: 'Giọng nam miền Trung chân thành, mộc mạc, nhịp điệu thong thả, mang âm sắc Đà Nẵng sâu lắng và ấm cúng.',
      gender: 'male',
      accent: 'central',
      category: 'warm',
      engineType: 'neural',
      remoteVoiceId: 'Fenrir', // Google Studio Neural: Grounded & Passionate Male
      edgeVoiceName: 'vi-VN-NamMinhNeural',
      nativeSystemVoiceName: 'vi-vn-x-vib-local',
      createdAt: DateTime(2026, 1, 1),
      defaultSpeed: 0.86,
      defaultPitch: 0.94,
      emotionPreset: 'empathetic',
      sampleText: 'Dạ chào bạn ạ! Rất vui được gặp bạn trong ngày hôm nay. Mình xin phép cùng bạn điểm qua các nội dung tiếp theo nhé.',
    ),

    // 8. ALEX (Song ngữ Anh - Việt hiện đại)
    VoiceModel(
      id: 'preset_alex_bilingual',
      name: 'Alex (Bilingual)',
      description: 'Giọng song ngữ Anh - Việt hiện đại, phát âm tiếng Anh cực chuẩn bản xứ kết hợp tiếng Việt tự nhiên, phù hợp trợ lý AI đa nhiệm.',
      gender: 'neutral',
      accent: 'intl',
      category: 'professional',
      engineType: 'neural',
      remoteVoiceId: 'Puck',
      edgeVoiceName: 'vi-VN-HoaiMyNeural',
      nativeSystemVoiceName: 'en-us-x-sfg-network',
      nativeSystemVoiceName: 'en-us-x-sfg-network',
      createdAt: DateTime(2026, 1, 1),
      defaultSpeed: 0.90,
      defaultPitch: 1.00,
      emotionPreset: 'natural',
      sampleText: 'Hello there! Tôi có thể chuyển đổi mượt mà giữa English và Tiếng Việt một cách tự nhiên và chính xác.',
    ),
  ];

  static VoiceModel get defaultVoice => allPresets.first;

  static VoiceModel findById(String id) {
    return allPresets.firstWhere(
      (v) => v.id == id,
      orElse: () => defaultVoice,
    );
  }
}
