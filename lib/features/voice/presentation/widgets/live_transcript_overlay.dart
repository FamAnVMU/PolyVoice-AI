import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class LiveTranscriptOverlay extends StatelessWidget {
  final String userTranscript;
  final String aiResponse;
  final String personaName;

  const LiveTranscriptOverlay({
    super.key,
    required this.userTranscript,
    required this.aiResponse,
    required this.personaName,
  });

  @override
  Widget build(BuildContext context) {
    if (userTranscript.isEmpty && aiResponse.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'Speak naturally to PolyVoice AI...',
            style: TextStyle(fontSize: 14, color: Colors.grey, fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCard.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.darkCardBorder),
      ),
      child: SingleChildScrollView(
        reverse: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (userTranscript.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('You: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accentCyan)),
                  Expanded(
                    child: Text(
                      userTranscript,
                      style: const TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                  ),
                ],
              ),
              const Divider(height: 16, color: AppColors.darkCardBorder),
            ],
            if (aiResponse.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$personaName: ',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accentPink),
                  ),
                  Expanded(
                    child: Text(
                      aiResponse,
                      style: const TextStyle(fontSize: 14.5, color: Colors.white, height: 1.4),
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
