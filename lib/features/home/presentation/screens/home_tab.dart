import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../character/data/character_library.dart';
import '../../../character/data/models/ai_character_model.dart';
import '../../../character/presentation/screens/character_editor_screen.dart';
import '../../../character/presentation/widgets/character_profile_dialog.dart';
import '../../../chat/presentation/bloc/chat_bloc.dart';
import '../../../chat/presentation/bloc/chat_event.dart';
import '../../../chat/presentation/bloc/chat_state.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../voice/presentation/screens/continuous_voice_screen.dart';

class HomeTab extends StatefulWidget {
  final VoidCallback onNavigateToDiscover;
  final VoidCallback onNavigateToMessages;

  const HomeTab({
    super.key,
    required this.onNavigateToDiscover,
    required this.onNavigateToMessages,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String? _currentlyPlayingCharId;

  void _previewVoice(AICharacterModel char) {
    setState(() {
      _currentlyPlayingCharId = char.id;
    });

    final settings = context.read<SettingsBloc>().state;
    final coordinator = context.read<ChatBloc>().coordinator;
    coordinator.ttsQueueManager.stopAndClear();
    coordinator.ttsQueueManager.enqueue(
      char.sampleGreeting,
      settings.voiceConfig,
      voiceConfig: char.voiceConfig,
      geminiApiKey: settings.apiKeys.geminiKey,
    );

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _currentlyPlayingCharId == char.id) {
        setState(() {
          _currentlyPlayingCharId = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder;

    final featuredCharacters = CharacterLibrary.getFeaturedCharacters();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Header: Greeting, User Avatar & Voice Mode Trigger
              BlocBuilder<ChatBloc, ChatState>(
                builder: (context, chatState) {
                  final profile = chatState.userProfile;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                profile.avatarEmoji,
                                style: const TextStyle(fontSize: 22),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Xin chào, ${profile.name} 👋',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "${profile.ageGroupLabel.split('(').first.trim()} • ${profile.responseStyleLabel}",
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.primaryLight,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Quick Voice Mode Button
                      IconButton(
                        tooltip: 'Chế độ đàm thoại trực tiếp',
                        icon: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.accentPink, AppColors.primary],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accentPink.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.mic_rounded, color: Colors.white, size: 20),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ContinuousVoiceScreen()),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              // Banner: Real-Time Multi-Character AI Architecture
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4834D4), Color(0xFF6C5CE7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '✨ ĐA NHÂN CÁCH AI',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Khám phá thế giới AI sống động',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mỗi nhân vật mang cá tính, chuyên môn, giọng nói riêng biệt và bộ nhớ cuộc trò chuyện hoàn toàn độc lập.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: widget.onNavigateToDiscover,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryDark,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text(
                        'Xem tất cả nhân vật →',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Section: My Custom Characters (Tùy chỉnh của tôi)
              BlocBuilder<ChatBloc, ChatState>(
                builder: (context, state) {
                  final customChars = state.customCharacters;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Nhân vật của tôi',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                              if (customChars.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentCyan.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${customChars.length}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.accentCyan,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const CharacterEditorScreen(
                                    mode: CharacterEditorMode.createScratch,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.add_rounded, size: 16, color: AppColors.primaryLight),
                            label: const Text(
                              'Tạo mới',
                              style: TextStyle(color: AppColors.primaryLight, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (customChars.isEmpty)
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const CharacterEditorScreen(
                                  mode: CharacterEditorMode.createScratch,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.35),
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.person_add_alt_1_rounded,
                                    color: AppColors.primaryLight,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Tạo nhân vật AI của riêng bạn',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Tùy chỉnh giọng nói, xưng hô, phong cách và tiểu sử theo ý thích.',
                                        style: TextStyle(fontSize: 11, color: textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.primaryLight),
                              ],
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          height: 195,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: customChars.length + 1,
                            separatorBuilder: (_, __) => const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              if (index == customChars.length) {
                                // Add New Button Card
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const CharacterEditorScreen(
                                          mode: CharacterEditorMode.createScratch,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: 140,
                                    decoration: BoxDecoration(
                                      color: cardBg,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: AppColors.primary.withValues(alpha: 0.35),
                                      ),
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary.withValues(alpha: 0.12),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.add_rounded,
                                              size: 24,
                                              color: AppColors.primaryLight,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Tạo thêm\nnhân vật',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }

                              final char = customChars[index];
                              return _buildCharacterMiniCard(
                                context,
                                char,
                                cardBg,
                                borderColor,
                                textPrimary,
                                textSecondary,
                                isDark,
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // Section: Featured Characters (Carousel)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Nhân vật nổi bật',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onNavigateToDiscover,
                    child: const Text(
                      'Khám phá thêm',
                      style: TextStyle(color: AppColors.primaryLight, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 205,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: featuredCharacters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final char = featuredCharacters[index];
                    return _buildCharacterMiniCard(
                      context,
                      char,
                      cardBg,
                      borderColor,
                      textPrimary,
                      textSecondary,
                      isDark,
                    );
                  },
                ),
              ),
              const SizedBox(height: 26),

              // Section: Recent Conversations
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Cuộc trò chuyện gần đây',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onNavigateToMessages,
                    child: const Text(
                      'Hộp thư',
                      style: TextStyle(color: AppColors.primaryLight, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              BlocBuilder<ChatBloc, ChatState>(
                builder: (context, state) {
                  final recentSessions = state.allSessions.where((s) => !s.isArchived).take(4).toList();

                  if (recentSessions.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.chat_bubble_outline_rounded, size: 36, color: Colors.grey),
                            const SizedBox(height: 8),
                            Text(
                              'Chưa có cuộc trò chuyện nào',
                              style: TextStyle(color: textSecondary, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: widget.onNavigateToDiscover,
                              child: const Text('Chọn một nhân vật để bắt đầu'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: recentSessions.map((session) {
                      final charAvatar = session.characterAvatar;
                      final charName = session.characterName;
                      final lastMessage = session.messages.isNotEmpty
                          ? session.messages.last.content
                          : 'Bắt đầu cuộc trò chuyện...';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [AppColors.primary, AppColors.accentCyan],
                              ),
                            ),
                            child: Center(
                              child: Text(charAvatar, style: const TextStyle(fontSize: 20)),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  charName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentCyan.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '🎙️ ${session.voiceConfig.voiceName}',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: AppColors.accentCyan,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                              if (session.isPinned)
                                const Icon(Icons.push_pin_rounded, size: 14, color: AppColors.warning),
                            ],
                          ),
                          subtitle: Text(
                            lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: textSecondary),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
                          onTap: () {
                            context.read<ChatBloc>().add(SwitchSessionEvent(session.id));
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const ChatScreen()),
                            );
                          },
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCharacterMiniCard(
    BuildContext context,
    AICharacterModel char,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    final isPlaying = _currentlyPlayingCharId == char.id;
    final isMale = char.gender == 'male';

    return GestureDetector(
      onTap: () => CharacterProfileDialog.show(context, char),
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isPlaying ? AppColors.accentCyan : borderColor,
            width: isPlaying ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isPlaying
                  ? AppColors.accentCyan.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: isPlaying ? 10 : 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isMale
                          ? [Colors.blue.shade600, AppColors.accentCyan]
                          : [Colors.pink.shade500, AppColors.primary],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(char.avatar, style: const TextStyle(fontSize: 20)),
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                  icon: Icon(
                    isPlaying ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                    size: 19,
                    color: isPlaying ? AppColors.accentCyan : AppColors.primaryLight,
                  ),
                  tooltip: 'Nghe thử giọng',
                  onPressed: () => _previewVoice(char),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    char.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: (isMale ? Colors.blue : Colors.pink).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isMale ? 'Nam' : 'Nữ',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      color: isMale ? Colors.blue : Colors.pink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '🎙️ ${char.voiceConfig.voiceName}',
              style: const TextStyle(
                fontSize: 9.5,
                color: AppColors.accentCyan,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Expanded(
              child: Text(
                char.shortDescription,
                style: TextStyle(fontSize: 10.5, color: textSecondary, height: 1.25),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: 28,
              child: ElevatedButton(
                onPressed: () {
                  context.read<ChatBloc>().add(CreateSessionWithCharacterEvent(char));
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ChatScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  foregroundColor: AppColors.primaryLight,
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Nhắn tin', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
