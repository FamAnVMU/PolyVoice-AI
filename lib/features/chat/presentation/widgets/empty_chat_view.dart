import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../settings/data/models/persona_model.dart';

class EmptyChatView extends StatelessWidget {
  final PersonaModel persona;
  final Function(String prompt) onSelectPrompt;

  const EmptyChatView({
    super.key,
    required this.persona,
    required this.onSelectPrompt,
  });

  List<String> get _quickPrompts {
    if (persona.id == 'cute_sweet_companion') {
      return [
        'Hôm nay cậu thế nào rồi nè? 🌸',
        'Kể cho mình nghe một câu chuyện ấm áp đi!',
        'Mình đang hơi mệt, an ủi mình một chút được không?',
      ];
    } else if (persona.id == 'anime_kouhai') {
      return [
        'Senpai! Hôm nay có nhiệm vụ gì cho em không? 🎀',
        'Gợi ý cho em một bộ anime hay xem cuối tuần này đi!',
        'Senpai thấy em có chăm chỉ không nè?',
      ];
    } else if (persona.id == 'polyglot_tutor') {
      return [
        'Can we practice daily English conversation?',
        'Hãy giải thích sự khác biệt giữa "affect" và "effect".',
        'Luyện phát âm và sửa ngữ pháp giúp tôi nhé!',
      ];
    } else {
      return [
        'Tóm tắt các xu hướng công nghệ nổi bật năm nay.',
        'Lên kế hoạch làm việc hiệu quả cho một ngày.',
        'Gợi ý 5 ý tưởng phát triển ứng dụng di động.',
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.accentPink],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Text(persona.avatarEmoji, style: const TextStyle(fontSize: 40)),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              persona.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                persona.description,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'CONVERSATION STARTERS',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: _quickPrompts.map((prompt) {
                return ActionChip(
                  label: Text(prompt, style: const TextStyle(fontSize: 12.5)),
                  avatar: const Icon(Icons.chat_bubble_outline, size: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  onPressed: () => onSelectPrompt(prompt),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
