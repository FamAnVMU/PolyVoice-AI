import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../character/data/character_library.dart';
import '../../../character/presentation/widgets/character_profile_dialog.dart';
import '../../../settings/data/models/persona_model.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../settings/presentation/bloc/settings_state.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../voice/presentation/screens/continuous_voice_screen.dart';
import '../bloc/chat_bloc.dart';
import '../bloc/chat_event.dart';
import '../bloc/chat_state.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/empty_chat_view.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isNearBottom = true;
  int _visibleMessageCount = 25;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    const threshold = 80.0;
    final nearBottom = (maxScroll - currentScroll) <= threshold;

    if (nearBottom != _isNearBottom) {
      setState(() {
        _isNearBottom = nearBottom;
      });
      context.read<ChatBloc>().add(SetAutoScrollLockEvent(!nearBottom));
    }

    // Lazy Loading Pagination (TASK 4): Load 25 earlier messages when scrolling near top
    if (currentScroll <= 60 && !_isNearBottom) {
      final total = context.read<ChatBloc>().state.messages.length;
      if (_visibleMessageCount < total) {
        setState(() {
          _visibleMessageCount = (_visibleMessageCount + 25).clamp(25, total);
        });
      }
    }
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (animated) {
      _scrollController.animateTo(
        maxScroll,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(maxScroll);
    }
  }

  void _showSessionMemoryDialog(BuildContext context) {
    final noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
        final borderColor = isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder;
        final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
        final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

        return BlocBuilder<ChatBloc, ChatState>(
          builder: (context, chatState) {
            final active = chatState.activeSession;
            final charName = active?.characterName ?? 'Nhân vật AI';
            final charAvatar = active?.characterAvatar ?? '🤖';
            final memoryNotes = active?.memoryNotes ?? const [];

            return Container(
              height: MediaQuery.of(sheetContext).size.height * 0.75,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: borderColor),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 14,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [AppColors.primary, AppColors.accentCyan]),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(charAvatar, style: const TextStyle(fontSize: 22)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              charName,
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textPrimary),
                            ),
                            Text(
                              'Ký ức & Ghi nhớ độc lập cho cuộc trò chuyện này',
                              style: TextStyle(fontSize: 11, color: textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Add note input
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: noteController,
                          decoration: InputDecoration(
                            hintText: 'Thêm ghi nhớ (ví dụ: Tôi thích code Dart)...',
                            hintStyle: TextStyle(fontSize: 12, color: textSecondary),
                            filled: true,
                            fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.add_circle_rounded, color: AppColors.primary, size: 28),
                        onPressed: () {
                          final text = noteController.text.trim();
                          if (text.isNotEmpty) {
                            context.read<ChatBloc>().add(AddMemoryNoteEvent(text));
                            noteController.clear();
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Các mục đã ghi nhớ (${memoryNotes.length}):',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
                      ),
                      if (memoryNotes.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            context.read<ChatBloc>().add(ClearMemoryNotesEvent());
                          },
                          child: const Text('Xóa tất cả', style: TextStyle(color: AppColors.error, fontSize: 12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  Expanded(
                    child: memoryNotes.isEmpty
                        ? Center(
                            child: Text(
                              'Chưa có ghi nhớ nào cho cuộc trò chuyện này.\nHãy thêm ghi nhớ để nhân vật AI hiểu rõ hơn về bạn!',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: textSecondary),
                            ),
                          )
                        : ListView.separated(
                            itemCount: memoryNotes.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.bookmark_rounded, size: 16, color: AppColors.primaryLight),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        memoryNotes[index],
                                        style: TextStyle(fontSize: 12, color: textPrimary),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ChatBloc, ChatState>(
      listenWhen: (prev, curr) {
        return (curr.messages.isNotEmpty && _isNearBottom) ||
            (curr.errorMessage != null && prev.errorMessage != curr.errorMessage);
      },
      listener: (context, state) {
        if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom(animated: false);
        });
      },
      child: Scaffold(
        appBar: AppBar(
          leading: Navigator.canPop(context)
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null,
          titleSpacing: Navigator.canPop(context) ? 0 : 16,
          title: BlocBuilder<ChatBloc, ChatState>(
            builder: (context, chatState) {
              return BlocBuilder<SettingsBloc, SettingsState>(
                builder: (context, settingsState) {
                  final active = chatState.activeSession;
                  final defaultChar = CharacterLibrary.getFeaturedCharacters().first;
                  final charName = active?.characterName ?? defaultChar.name;
                  final charAvatar = active?.characterAvatar ?? defaultChar.avatar;
                  final voiceName = active?.voiceConfig?.voiceName ?? 'Giọng mặc định';
                  final provider = settingsState.apiKeys.selectedProvider.toUpperCase();
                  final model = settingsState.apiKeys.selectedModel;

                  // Find full character if available
                  final matchedChar = chatState.allCharacters.firstWhere(
                    (c) => c.id == active?.characterId,
                    orElse: () => defaultChar,
                  );

                  return GestureDetector(
                    onTap: () => CharacterProfileDialog.show(context, matchedChar),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [AppColors.primary, AppColors.accentCyan],
                            ),
                          ),
                          child: Center(
                            child: Text(charAvatar, style: const TextStyle(fontSize: 18)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      charName,
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.primaryLight),
                                ],
                              ),
                              Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: AppColors.accentNeon,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      '🎙️ $voiceName • ${active != null && active.memoryNotes.isNotEmpty ? '🧠 ${active.memoryNotes.length} • ' : ''}$provider ($model)',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          actions: [
            // Button to enter Continuous Real-Time Voice Mode
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.accentPink, AppColors.primary],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.spatial_audio_off_rounded, size: 18, color: Colors.white),
              ),
              tooltip: 'Continuous Voice Mode',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ContinuousVoiceScreen()),
                );
              },
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (val) {
                if (val == 'memory') {
                  _showSessionMemoryDialog(context);
                } else if (val == 'settings') {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                } else if (val == 'clear') {
                  context.read<ChatBloc>().add(ClearChatEvent());
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'memory',
                  child: Row(
                    children: [
                      Icon(Icons.psychology_rounded, size: 18, color: AppColors.accentCyan),
                      SizedBox(width: 10),
                      Text('Ký ức cuộc trò chuyện'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings, size: 18),
                      SizedBox(width: 10),
                      Text('Settings & Keys'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                      SizedBox(width: 10),
                      Text('Xóa tin nhắn trong cuộc này', style: TextStyle(color: AppColors.error)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                // Chat Message List
                Expanded(
                  child: BlocBuilder<ChatBloc, ChatState>(
                    builder: (context, chatState) {
                      if (chatState.messages.isEmpty) {
                        final active = chatState.activeSession;
                        final fallback = context.read<SettingsBloc>().state.activePersona;
                        final effectivePersona = PersonaModel(
                          id: active?.characterId ?? fallback.id,
                          name: active?.characterName ?? fallback.name,
                          description: 'Nhân cách AI',
                          avatarEmoji: active?.characterAvatar ?? fallback.avatarEmoji,
                          systemPrompt: active?.systemPrompt ?? fallback.systemPrompt,
                        );

                        return EmptyChatView(
                          persona: effectivePersona,
                          onSelectPrompt: (prompt) {
                            context.read<ChatBloc>().add(SendTextMessageEvent(prompt));
                          },
                        );
                      }

                      final allMessages = chatState.messages;
                      final startIndex = allMessages.length > _visibleMessageCount
                          ? allMessages.length - _visibleMessageCount
                          : 0;
                      final displayMessages = allMessages.sublist(startIndex);
                      final hasMore = startIndex > 0;

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(top: 10, bottom: 20),
                        itemCount: displayMessages.length + (hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (hasMore && index == 0) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: ActionChip(
                                  avatar: const Icon(Icons.history_rounded, size: 16),
                                  label: Text(
                                    'Tải thêm tin nhắn cũ ($startIndex còn lại)',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _visibleMessageCount = (_visibleMessageCount + 25)
                                          .clamp(25, allMessages.length);
                                    });
                                  },
                                ),
                              ),
                            );
                          }

                          final actualMsgIndex = hasMore ? index - 1 : index;
                          final msg = displayMessages[actualMsgIndex];
                          final isSpeakingThis = chatState.isSpeakingTts &&
                              chatState.activeSpeakingMessageId == msg.id;

                          return MessageBubble(
                            message: msg,
                            isSpeaking: isSpeakingThis,
                            onSpeakPressed: () {
                              context.read<ChatBloc>().add(
                                    SpeakMessageTtsEvent(messageId: msg.id, text: msg.content),
                                  );
                            },
                            onStopSpeakingPressed: () {
                              context.read<ChatBloc>().add(StopTtsPlaybackEvent());
                            },
                          );
                        },
                      );
                    },
                  ),
                ),

                // Chat Input Bar
                BlocBuilder<ChatBloc, ChatState>(
                  builder: (context, chatState) {
                    return ChatInputBar(
                      isStreaming: chatState.isStreaming,
                      isListening: chatState.isListeningStt,
                      transcriptPreview: chatState.sttTranscriptPreview,
                      onSendMessage: (text) {
                        context.read<ChatBloc>().add(SendTextMessageEvent(text));
                      },
                      onStartListening: () {
                        context.read<ChatBloc>().add(StartTapToSpeakEvent());
                      },
                      onStopListening: () {
                        context.read<ChatBloc>().add(StopTapToSpeakEvent());
                      },
                    );
                  },
                ),
              ],
            ),

            // Floating Scroll to Bottom Button (Shown when auto-scroll is locked)
            if (!_isNearBottom)
              Positioned(
                bottom: 80,
                right: 16,
                child: FloatingActionButton.small(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  onPressed: () => _scrollToBottom(animated: true),
                  child: const Icon(Icons.arrow_downward, size: 18),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
