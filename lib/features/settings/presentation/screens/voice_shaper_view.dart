import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';

class VoiceShaperView extends StatelessWidget {
  const VoiceShaperView({super.key});

  static const List<Map<String, String>> supportedLanguages = [
    {'code': 'vi-VN', 'name': 'Vietnamese (Tiếng Việt)'},
    {'code': 'ja-JP', 'name': 'Japanese (日本語)'},
    {'code': 'en-US', 'name': 'English (United States)'},
    {'code': 'ko-KR', 'name': 'Korean (한국어)'},
  ];

  void _testVoice(BuildContext context, SettingsState state) {
    final tts = context.read<SettingsBloc>().ttsService;
    final lang = state.voiceConfig.languageCode;

    String sampleText = 'Xin chào! Mình là PolyVoice AI, rất vui được trò chuyện cùng bạn!';
    if (lang.startsWith('ja')) {
      sampleText = 'こんにちは先輩！ポリボイスAIです。よろしくお願いします！';
    } else if (lang.startsWith('en')) {
      sampleText = 'Hello there! I am PolyVoice AI, your real-time voice companion.';
    } else if (lang.startsWith('ko')) {
      sampleText = '안녕하세요! 저는 폴리보이스 AI입니다. 만나서 반가워요!';
    }

    tts.speak(sampleText, config: state.voiceConfig);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        final config = state.voiceConfig;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Voice Tuning Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.15),
                      AppColors.accentPink.withValues(alpha: 0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.graphic_eq_rounded, color: AppColors.accentPink, size: 32),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Acoustic Voice Shaper',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Tune pitch, speed, and choose system voices. Set pitch to 1.3x - 1.5x for cute/anime tones.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Text(
                'TARGET LANGUAGE',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.grey),
              ),
              const SizedBox(height: 8),

              // Language Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.darkCardBorder),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: config.languageCode,
                    items: supportedLanguages.map((lang) {
                      return DropdownMenuItem<String>(
                        value: lang['code'],
                        child: Text(lang['name']!),
                      );
                    }).toList(),
                    onChanged: (newLang) {
                      if (newLang == null) return;
                      final updated = config.copyWith(languageCode: newLang, voiceName: null, voiceLocale: null);
                      context.read<SettingsBloc>().add(UpdateVoiceConfigEvent(updated));
                      context.read<SettingsBloc>().add(LoadAvailableVoicesEvent(newLang));
                    },
                  ),
                ),
              ),

              const SizedBox(height: 24),
              const Text(
                'SYSTEM VOICE SYNTHESIZER',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.grey),
              ),
              const SizedBox(height: 8),

              // Voice Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.darkCardBorder),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    isExpanded: true,
                    value: config.voiceName,
                    hint: const Text('Default System Voice Engine'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Default System Voice'),
                      ),
                      ...state.availableVoices.map((v) {
                        return DropdownMenuItem<String?>(
                          value: v['name'],
                          child: Text(
                            '${v['name']} (${v['locale']})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ],
                    onChanged: (selectedVoiceName) {
                      final match = state.availableVoices.firstWhere(
                        (v) => v['name'] == selectedVoiceName,
                        orElse: () => {},
                      );
                      final updated = config.copyWith(
                        voiceName: selectedVoiceName,
                        voiceLocale: match['locale'],
                      );
                      context.read<SettingsBloc>().add(UpdateVoiceConfigEvent(updated));
                    },
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Pitch Slider (0.5x to 2.0x)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Vocal Pitch', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    '${config.pitch.toStringAsFixed(2)}x ${config.pitch >= 1.3 ? "(Cute/Young)" : config.pitch < 0.9 ? "(Deep)" : "(Natural)"}',
                    style: const TextStyle(color: AppColors.accentPink, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Slider(
                value: config.pitch,
                min: 0.5,
                max: 2.0,
                divisions: 30,
                onChanged: (val) {
                  final updated = config.copyWith(pitch: val);
                  context.read<SettingsBloc>().add(UpdateVoiceConfigEvent(updated));
                },
              ),

              const SizedBox(height: 16),

              // Speed / Rate Slider (0.5x to 1.5x)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Speaking Rate / Speed', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    '${config.rate.toStringAsFixed(2)}x',
                    style: const TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Slider(
                value: config.rate,
                min: 0.5,
                max: 1.5,
                divisions: 20,
                onChanged: (val) {
                  final updated = config.copyWith(rate: val);
                  context.read<SettingsBloc>().add(UpdateVoiceConfigEvent(updated));
                },
              ),

              const SizedBox(height: 16),

              // Volume Slider (0.0 to 1.0)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Volume', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    '${(config.volume * 100).toInt()}%',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Slider(
                value: config.volume,
                min: 0.0,
                max: 1.0,
                divisions: 20,
                onChanged: (val) {
                  final updated = config.copyWith(volume: val);
                  context.read<SettingsBloc>().add(UpdateVoiceConfigEvent(updated));
                },
              ),

              const SizedBox(height: 28),

              // Test Voice Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _testVoice(context, state),
                  icon: const Icon(Icons.volume_up),
                  label: const Text('Preview Acoustic Tuning'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentPink,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }
}
