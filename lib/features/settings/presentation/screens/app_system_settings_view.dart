import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../character/data/character_library.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';

class AppSystemSettingsView extends StatelessWidget {
  const AppSystemSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final auditIssues = CharacterLibrary.auditCharacterVoices();

    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('GIAO DIỆN & HIỂN THỊ',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary)),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: SwitchListTile(
                  title: Text('Chế độ Tối (Dark Mode)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
                  subtitle: Text('Giao diện tối màu bảo vệ mắt và tiết kiệm pin OLED',
                      style: TextStyle(fontSize: 12, color: textSecondary)),
                  value: state.themeMode == ThemeMode.dark,
                  activeColor: AppColors.primary,
                  onChanged: (_) {
                    context.read<SettingsBloc>().add(ToggleThemeModeEvent());
                  },
                ),
              ),
              const SizedBox(height: 24),

              Text('TOÀN VẸN HỆ THỐNG GIỌNG NÓI & NHÂN VẬT',
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          auditIssues.isEmpty ? Icons.verified_rounded : Icons.warning_rounded,
                          color: auditIssues.isEmpty ? AppColors.success : AppColors.warning,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            auditIssues.isEmpty
                                ? '100% Nhân vật đã xác thực giọng nói hợp lệ'
                                : 'Phát hiện ${auditIssues.length} vấn đề cấu hình',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: auditIssues.isEmpty ? AppColors.success : AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tất cả 16 nhân vật trong thư viện và các nhân vật tùy chỉnh đều được liên kết cố định với Voice Configuration hợp lệ, kiểm soát giới tính và tốc độ độc lập.',
                      style: TextStyle(fontSize: 12, color: textSecondary, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text('THÔNG TIN ỨNG DỤNG',
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
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Tên ứng dụng', style: TextStyle(fontSize: 13, color: textSecondary)),
                        Text('PolyVoice AI', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Phiên bản', style: TextStyle(fontSize: 13, color: textSecondary)),
                        const Text('v1.2.0+9 (Production)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryLight)),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Tác giả', style: TextStyle(fontSize: 13, color: textSecondary)),
                        Text('FamAn', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
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
  }
}
