import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../services/pipeline/voice_pipeline_coordinator.dart';
import '../../../chat/presentation/bloc/chat_bloc.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../settings/presentation/bloc/settings_state.dart';
import '../widgets/live_transcript_overlay.dart';
import '../widgets/pulsing_orb.dart';
import '../widgets/voice_control_panel.dart';

class ContinuousVoiceScreen extends StatefulWidget {
  const ContinuousVoiceScreen({super.key});

  @override
  State<ContinuousVoiceScreen> createState() => _ContinuousVoiceScreenState();
}

class _ContinuousVoiceScreenState extends State<ContinuousVoiceScreen> {
  PipelineStatus _status = PipelineStatus.idle;
  String _userTranscript = '';
  String _aiResponse = '';
  bool _isMuted = false;

  late VoicePipelineCoordinator _coordinator;

  StreamSubscription<PipelineStatus>? _statusSub;
  StreamSubscription<String>? _transcriptSub;
  StreamSubscription<String>? _aiTokenSub;
  StreamSubscription<String>? _aiFinishSub;
  StreamSubscription<String>? _errorSub;

  @override
  void initState() {
    super.initState();
    _coordinator = context.read<ChatBloc>().coordinator;

    _bindPipelineListeners();

    // Auto-start listening on screen entry
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startListening();
    });
  }

  void _bindPipelineListeners() {
    _statusSub = _coordinator.onStatusChangedStream.listen((newStatus) {
      if (mounted) {
        setState(() {
          _status = newStatus;
        });
      }
    });

    _transcriptSub = _coordinator.onUserTranscriptUpdatedStream.listen((text) {
      if (mounted) {
        setState(() {
          _userTranscript = text;
        });
      }
    });

    _aiTokenSub = _coordinator.onAiTokenReceivedStream.listen((streamed) {
      if (mounted) {
        setState(() {
          _aiResponse = streamed;
        });
      }
    });

    _aiFinishSub = _coordinator.onAiResponseFinishedStream.listen((finishedText) {
      if (mounted) {
        setState(() {
          _aiResponse = finishedText;
        });
      }
    });

    _errorSub = _coordinator.onErrorStream.listen((err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
  }

  void _startListening() {
    if (_isMuted) return;
    setState(() {
      _aiResponse = '';
    });
    final settings = context.read<SettingsBloc>().state;
    _coordinator.startListening(
      apiKeys: settings.apiKeys,
      voiceConfig: settings.voiceConfig,
    );
  }

  void _stopListeningAndSend() {
    final settings = context.read<SettingsBloc>().state;
    final chatBloc = context.read<ChatBloc>();

    _coordinator.stopListeningAndProcess(
      conversationHistory: chatBloc.state.messages,
      apiKeys: settings.apiKeys,
      persona: settings.activePersona,
      voiceConfig: settings.voiceConfig,
      fallbackTranscript: _userTranscript,
    );
  }

  void _handleOrbTap() {
    if (_status == PipelineStatus.speaking) {
      // Barge-in: Interrupt AI and start listening
      _coordinator.interrupt();
      _startListening();
    } else if (_status == PipelineStatus.listening) {
      // Finished speaking: Send query to LLM
      _stopListeningAndSend();
    } else if (_status == PipelineStatus.idle || _status == PipelineStatus.error) {
      // Start listening
      _startListening();
    }
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _transcriptSub?.cancel();
    _aiTokenSub?.cancel();
    _aiFinishSub?.cancel();
    _errorSub?.cancel();
    _coordinator.interrupt();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: BlocBuilder<SettingsBloc, SettingsState>(
          builder: (context, settingsState) {
            final persona = settingsState.activePersona;

            return Column(
              children: [
                // Header Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.darkCard,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.darkCardBorder),
                        ),
                        child: Text(persona.avatarEmoji, style: const TextStyle(fontSize: 22)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              persona.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '${settingsState.apiKeys.selectedProvider.toUpperCase()} • Live Voice Mode',
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_downward, color: Colors.white70),
                        tooltip: 'Return to Chat View',
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Central Interactive Pulsing Orb Visualizer
                Center(
                  child: PulsingOrb(
                    status: _status,
                    onTap: _handleOrbTap,
                  ),
                ),

                const Spacer(),

                // Live Streaming Transcript Overlay
                LiveTranscriptOverlay(
                  userTranscript: _userTranscript,
                  aiResponse: _aiResponse,
                  personaName: persona.name,
                ),

                const SizedBox(height: 16),

                // Controls: Mute, Interrupt, Close
                VoiceControlPanel(
                  isSpeaking: _status == PipelineStatus.speaking,
                  isMuted: _isMuted,
                  onToggleMute: () {
                    setState(() {
                      _isMuted = !_isMuted;
                      if (_isMuted) {
                        _coordinator.interrupt();
                      } else {
                        _startListening();
                      }
                    });
                  },
                  onInterrupt: () {
                    _coordinator.interrupt();
                  },
                  onClose: () => Navigator.pop(context),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
