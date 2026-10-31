import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../voice/data/preset_voices.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';

/// Technical settings view for configuring TTS Engine infrastructure and ElevenLabs key.
/// Voice selection and character personalities are managed per-character, NOT globally.
class VoiceEngineSettingsView extends StatefulWidget {
  const VoiceEngineSettingsView({super.key});

  @override
  State<VoiceEngineSettingsView> createState() => _VoiceEngineSettingsViewState();
}

class _VoiceEngineSettingsViewState extends State<VoiceEngineSettingsView> {
  final TextEditingController _elevenLabsKeyController = TextEditingController();
  bool _isPlayingTest = false;

  @override
  void initState() {
    super.initState();
    final currentKey = context.read<SettingsBloc>().state.voiceConfig.elevenLabsApiKey;
    _elevenLabsKeyController.text = currentKey;
  }

  @override
  void dispose() {
    _elevenLabsKeyController.dispose();
    super.dispose();
  }

  Future<void> _testEngine(String engine, SettingsState state) async {
    final tts = context.read<SettingsBloc>().ttsService;
    if (_isPlayingTest) {
      await tts.stop();
      setState(() => _isPlayingTest = false);
      return;
    }

    setState(() => _isPlayingTest = true);
    try {
      await tts.stop();
      await tts.speak(
        'Xin chào! Đây là âm thanh thử nghiệm hạ tầng giọng nói của PolyVoice AI.',
        config: state.voiceConfig.copyWith(voiceEngine: engine),
        voice: PresetVoices.defaultFemaleVoice,
        geminiApiKey: state.apiKeys.geminiKey,
      );
    } finally {
      if (mounted) setState(() => _isPlayingTest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        final currentEngine = state.voiceConfig.voiceEngine;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.primaryLight, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Cài đặt hạ tầng kỹ thuật tạo giọng nói. Tính cách và giọng riêng biệt được quản lý độc lập theo từng nhân vật.',
                        style: TextStyle(fontSize: 12, color: textPrimary, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Text('LỰA CHỌN ĐỘNG CƠ TTS CHÍNH',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary)),
              const SizedBox(height: 10),

              // Engine 1: Edge TTS
              _buildEngineCard(
                title: 'Microsoft Edge Neural TTS',
                badge: 'Khuyên dùng • Miễn phí 100%',
                description:
                    'Giọng đọc chuẩn phát thanh viên truyền hình (Hoài My & Nam Minh). Không tốn phí, độ trễ cực thấp.',
                engineKey: AppConstants.voiceEngineNeural,
                currentEngine: currentEngine,
                cardBg: cardBg,
                borderColor: borderColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onSelected: () {
                  final updated = state.voiceConfig.copyWith(voiceEngine: AppConstants.voiceEngineNeural);
                  context.read<SettingsBloc>().add(UpdateVoiceConfigEvent(updated));
                },
                onTest: () => _testEngine(AppConstants.voiceEngineNeural, state),
              ),
              const SizedBox(height: 12),

              // Engine 2: Gemini Studio Neural
              _buildEngineCard(
                title: 'Google Gemini Studio Audio',
                badge: 'Studio Realism • Dùng API Key',
                description: 'Tận dụng Gemini Flash Audio qua API Key của bạn để tạo ngữ điệu tự nhiên như người thật.',
                engineKey: 'gemini',
                currentEngine: currentEngine,
                cardBg: cardBg,
                borderColor: borderColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onSelected: () {
                  final updated = state.voiceConfig.copyWith(voiceEngine: 'gemini');
                  context.read<SettingsBloc>().add(UpdateVoiceConfigEvent(updated));
                },
                onTest: () => _testEngine('gemini', state),
              ),
              const SizedBox(height: 12),

              // Engine 3: ElevenLabs Voice Cloning
              _buildEngineCard(
                title: 'ElevenLabs Cloud TTS',
                badge: 'Cao cấp • Cần API Key',
                description: 'Công nghệ sao chép giọng nói cao cấp. Cần nhập ElevenLabs API Key bên dưới.',
                engineKey: AppConstants.voiceEngineElevenLabs,
                currentEngine: currentEngine,
                cardBg: cardBg,
                borderColor: borderColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onSelected: () {
                  final updated = state.voiceConfig.copyWith(voiceEngine: AppConstants.voiceEngineElevenLabs);
                  context.read<SettingsBloc>().add(UpdateVoiceConfigEvent(updated));
                },
                onTest: () => _testEngine(AppConstants.voiceEngineElevenLabs, state),
              ),
              const SizedBox(height: 12),

              // Engine 4: Local Device TTS
              _buildEngineCard(
                title: 'Local Device TTS (Offline)',
                badge: 'Hệ thống thiết bị',
                description: 'Động cơ Text-to-Speech mặc định của Android/iOS. Hoạt động offline khi không có mạng.',
                engineKey: AppConstants.voiceEngineDevice,
                currentEngine: currentEngine,
                cardBg: cardBg,
                borderColor: borderColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onSelected: () {
                  final updated = state.voiceConfig.copyWith(voiceEngine: AppConstants.voiceEngineDevice);
                  context.read<SettingsBloc>().add(UpdateVoiceConfigEvent(updated));
                },
                onTest: () => _testEngine(AppConstants.voiceEngineDevice, state),
              ),
              const SizedBox(height: 24),

              // ElevenLabs API Key section
              Text('CẤU HÌNH ELEVENLABS API KEY',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _elevenLabsKeyController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'ElevenLabs API Key',
                        hintText: 'Nhập sk_... hoặc API Key ElevenLabs',
                        prefixIcon: Icon(Icons.vpn_key_outlined, size: 20),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                      icon: const Icon(Icons.save_rounded, size: 18, color: Colors.white),
                      label: const Text('Lưu ElevenLabs Key', style: TextStyle(color: Colors.white)),
                      onPressed: () {
                        final key = _elevenLabsKeyController.text.trim();
                        final updated = state.voiceConfig.copyWith(elevenLabsApiKey: key);
                        context.read<SettingsBloc>().add(UpdateVoiceConfigEvent(updated));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã cập nhật cấu hình ElevenLabs API Key thành công!'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEngineCard({
    required String title,
    required String badge,
    required String description,
    required String engineKey,
    required String currentEngine,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required VoidCallback onSelected,
    required VoidCallback onTest,
  }) {
    final isSelected = currentEngine == engineKey;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.primary : borderColor,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Radio<String>(
                value: engineKey,
                groupValue: currentEngine,
                onChanged: (_) => onSelected(),
                activeColor: AppColors.primary,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.volume_up_rounded, color: AppColors.primaryLight),
                tooltip: 'Thử nghiệm động cơ này',
                onPressed: onTest,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Text(description, style: TextStyle(fontSize: 12, color: textSecondary, height: 1.35)),
          ),
        ],
      ),
    );
  }
}
