import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../chat/presentation/bloc/chat_bloc.dart';
import '../../../chat/presentation/bloc/chat_event.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../data/models/ai_character_model.dart';
import '../screens/character_editor_screen.dart';

class CharacterProfileDialog extends StatefulWidget {
  final AICharacterModel character;

  const CharacterProfileDialog({
    super.key,
    required this.character,
  });

  static Future<void> show(BuildContext context, AICharacterModel character) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CharacterProfileDialog(character: character),
    );
  }

  @override
  State<CharacterProfileDialog> createState() => _CharacterProfileDialogState();
}

class _CharacterProfileDialogState extends State<CharacterProfileDialog> {
  bool _isPlayingPreview = false;

  @override
  void dispose() {
    // Stop TTS if user closes modal sheet while speaking
    if (_isPlayingPreview) {
      try {
        context.read<ChatBloc>().coordinator.ttsQueueManager.stopAndClear();
      } catch (_) {}
    }
    super.dispose();
  }

  Future<void> _toggleVoicePreview() async {
    final coordinator = context.read<ChatBloc>().coordinator;
    final settings = context.read<SettingsBloc>().state;

    if (_isPlayingPreview) {
      await coordinator.ttsQueueManager.stopAndClear();
      if (mounted) setState(() => _isPlayingPreview = false);
      return;
    }

    setState(() => _isPlayingPreview = true);

    await coordinator.ttsQueueManager.stopAndClear();

    // Natural preview sentence
    final previewText = widget.character.sampleGreeting.trim().isNotEmpty
        ? widget.character.sampleGreeting
        : 'Xin chào! Rất vui được gặp bạn. Hôm nay bạn muốn cùng tôi trò chuyện về điều gì? Tôi luôn sẵn sàng lắng nghe và chia sẻ với bạn.';

    void onFinished() {
      if (mounted) {
        setState(() => _isPlayingPreview = false);
      }
    }

    coordinator.ttsQueueManager.addFinishedListener(onFinished);

    coordinator.ttsQueueManager.enqueue(
      previewText,
      settings.voiceConfig,
      voiceConfig: widget.character.voiceConfig,
      geminiApiKey: settings.apiKeys.geminiKey,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightSurface;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
          width: 1,
        ),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Header: Avatar, Name, Category
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.accentCyan],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      widget.character.avatar,
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.character.name,
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                          ),
                          if (widget.character.isCustom)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: AppColors.accentCyan.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Tùy chỉnh',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.accentCyan),
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, size: 16, color: AppColors.warning),
                                const SizedBox(width: 3),
                                Text(
                                  widget.character.rating.toString(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.warning,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            widget.character.categoryLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primaryLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: (widget.character.gender == 'male' ? Colors.blue : Colors.pink).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.character.gender == 'male' ? 'Nam' : 'Nữ',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: widget.character.gender == 'male' ? Colors.blue : Colors.pink,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Phong cách: ${widget.character.speakingStyle}',
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Short Description
            Text(
              widget.character.shortDescription,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),

            // Detailed Bio Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.psychology_rounded, size: 18, color: AppColors.accentCyan),
                      const SizedBox(width: 8),
                      Text(
                        'Tiểu sử & Tính cách',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.character.detailedBio,
                    style: TextStyle(fontSize: 13, color: textSecondary, height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Dedicated Voice Configuration Box with Interactive Preview
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isPlayingPreview
                      ? AppColors.primary
                      : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                  width: _isPlayingPreview ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isPlayingPreview ? Icons.graphic_eq_rounded : Icons.record_voice_over_rounded,
                        size: 20,
                        color: _isPlayingPreview ? AppColors.accentNeon : AppColors.primaryLight,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Giọng nói riêng: ${widget.character.voiceConfig.voiceName} (${widget.character.voiceConfig.speed}x • ${widget.character.voiceConfig.pitch}p)',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lời chào mẫu: "${widget.character.sampleGreeting}"',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Real Preview Button (Nghe thử giọng nói trước khi chat)
                  OutlinedButton.icon(
                    onPressed: _toggleVoicePreview,
                    icon: Icon(
                      _isPlayingPreview ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                      size: 20,
                      color: _isPlayingPreview ? AppColors.error : AppColors.primaryLight,
                    ),
                    label: Text(
                      _isPlayingPreview ? 'Dừng phát âm thử' : '▶ Nghe thử giọng nói trước khi chat',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _isPlayingPreview ? AppColors.error : AppColors.primaryLight,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: _isPlayingPreview ? AppColors.error : AppColors.primaryLight,
                        width: 1.2,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: (_isPlayingPreview ? AppColors.error : AppColors.primary)
                          .withValues(alpha: 0.08),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tags
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.character.tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '#$tag',
                    style: TextStyle(fontSize: 11, color: textSecondary),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // BUTTON 1: Bắt đầu trò chuyện ngay
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                context.read<ChatBloc>().add(CreateSessionWithCharacterEvent(widget.character));
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ChatScreen()),
                );
              },
              icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
              label: Text(
                'Trò chuyện ngay với ${widget.character.name}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
            ),
            const SizedBox(height: 10),

            // BUTTON 2: Tùy chỉnh nhân vật (Custom Character)
            if (!widget.character.isCustom)
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CharacterEditorScreen(
                        baseCharacter: widget.character,
                        mode: CharacterEditorMode.customizeBase,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: Text('Tùy chỉnh giọng từ ${widget.character.name}'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryLight,
                  side: const BorderSide(color: AppColors.primaryLight),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CharacterEditorScreen(
                              editingCharacter: widget.character,
                              mode: CharacterEditorMode.editCustom,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('Chỉnh sửa'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.read<ChatBloc>().add(DeleteCustomCharacterEvent(widget.character.id));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Đã xóa nhân vật tùy chỉnh "${widget.character.name}"'),
                            backgroundColor: AppColors.warning,
                          ),
                        );
                      },
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 16),
                      label: const Text('Xóa', style: TextStyle(color: AppColors.error)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
