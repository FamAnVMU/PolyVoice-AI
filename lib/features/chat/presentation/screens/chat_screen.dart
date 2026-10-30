import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    final threshold = 80.0;
    final nearBottom = (maxScroll - currentScroll) <= threshold;

    if (nearBottom != _isNearBottom) {
      setState(() {
        _isNearBottom = nearBottom;
      });
      context.read<ChatBloc>().add(SetAutoScrollLockEvent(!nearBottom));
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
          titleSpacing: 0,
          title: BlocBuilder<SettingsBloc, SettingsState>(
            builder: (context, settingsState) {
              final persona = settingsState.activePersona;
              final provider = settingsState.apiKeys.selectedProvider.toUpperCase();

              return Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.accentCyan],
                      ),
                    ),
                    child: Center(
                      child: Text(persona.avatarEmoji, style: const TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        persona.name,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
                          Text(
                            '$provider BYOK • Client-Side',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          actions: [
            // Button to enter Continuous Real-Time Voice Mode
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
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
                if (val == 'settings') {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                } else if (val == 'clear') {
                  context.read<ChatBloc>().add(ClearChatEvent());
                }
              },
              itemBuilder: (context) => [
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
                      Text('Clear Chat History', style: TextStyle(color: AppColors.error)),
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
                        final persona = context.read<SettingsBloc>().state.activePersona;
                        return EmptyChatView(
                          persona: persona,
                          onSelectPrompt: (prompt) {
                            context.read<ChatBloc>().add(SendTextMessageEvent(prompt));
                          },
                        );
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(top: 10, bottom: 20),
                        itemCount: chatState.messages.length,
                        itemBuilder: (context, index) {
                          final msg = chatState.messages[index];
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
