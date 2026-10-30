import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class VoiceControlPanel extends StatelessWidget {
  final bool isSpeaking;
  final bool isMuted;
  final VoidCallback onToggleMute;
  final VoidCallback onInterrupt;
  final VoidCallback onClose;

  const VoiceControlPanel({
    super.key,
    required this.isSpeaking,
    required this.isMuted,
    required this.onToggleMute,
    required this.onInterrupt,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Close button
          Container(
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.darkCardBorder),
            ),
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white70),
              tooltip: 'Close Voice Mode',
              onPressed: onClose,
            ),
          ),

          // Mute Mic Toggle Button
          Container(
            decoration: BoxDecoration(
              color: isMuted ? AppColors.error.withValues(alpha: 0.2) : AppColors.darkCard,
              shape: BoxShape.circle,
              border: Border.all(
                color: isMuted ? AppColors.error : AppColors.darkCardBorder,
              ),
            ),
            child: IconButton(
              icon: Icon(
                isMuted ? Icons.mic_off : Icons.mic,
                color: isMuted ? AppColors.error : Colors.white,
              ),
              tooltip: isMuted ? 'Unmute Mic' : 'Mute Mic',
              onPressed: onToggleMute,
            ),
          ),

          // Interrupt / Barge-In Button (Prominently active when AI is speaking)
          Container(
            decoration: BoxDecoration(
              color: isSpeaking ? AppColors.accentPink.withValues(alpha: 0.2) : AppColors.darkCard,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSpeaking ? AppColors.accentPink : AppColors.darkCardBorder,
              ),
            ),
            child: IconButton(
              icon: Icon(
                Icons.stop_circle_outlined,
                color: isSpeaking ? AppColors.accentPink : Colors.grey,
              ),
              tooltip: 'Interrupt AI (Barge-in)',
              onPressed: onInterrupt,
            ),
          ),
        ],
      ),
    );
  }
}
