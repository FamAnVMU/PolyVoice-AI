import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../chat/presentation/bloc/chat_bloc.dart';
import '../../../chat/presentation/bloc/chat_event.dart';
import '../../../chat/presentation/bloc/chat_state.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../settings/presentation/bloc/settings_event.dart';
import '../../../settings/presentation/bloc/settings_state.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../data/models/user_profile_model.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final List<String> _avatarEmojis = ['👤', '👩‍💻', '👨‍🎓', '🌟', '🐱', '🌸', '⚡', '🚀', '🧠', '🎨', '💼', '☕'];
  final List<String> _pronouns = [
    'Bạn - Mình',
    'Em - Anh/Chị',
    'Con - Bác/Cô/Chú',
    'Thầy - Em',
    'Tôi - Bạn',
    'Mặc định',
  ];

  void _showEditProfileSheet(BuildContext context, UserProfileModel current) {
    final nameController = TextEditingController(text: current.name);
    final instructionController = TextEditingController(text: current.customInstruction);
    String selectedEmoji = current.avatarEmoji;
    String selectedAge = current.ageGroup;
    String selectedStyle = current.responseStyle;
    String selectedPronoun = current.preferredPronoun;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
        final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
        final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
        final borderColor = isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(sheetContext).size.height * 0.88,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: borderColor),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
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
                    Text(
                      'Hồ sơ & Cá nhân hóa AI',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Các thiết lập này sẽ hướng dẫn AI xưng hô và điều chỉnh độ sâu câu trả lời theo độ tuổi của bạn.',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                    const SizedBox(height: 18),

                    // Avatar Emoji Selector
                    Text('Chọn biểu tượng đại diện:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _avatarEmojis.map((emoji) {
                        final isSelected = selectedEmoji == emoji;
                        return GestureDetector(
                          onTap: () => setModalState(() => selectedEmoji = emoji),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary.withOpacity(0.25) : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? AppColors.primary : borderColor,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Center(
                              child: Text(emoji, style: const TextStyle(fontSize: 22)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Name Field
                    Text('Tên của bạn:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        hintText: 'Nhập tên của bạn...',
                        filled: true,
                        fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderColor)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Age Group Selector
                    Text('Nhóm lứa tuổi của bạn:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
                    const SizedBox(height: 6),
                    _buildAgeOption('kids', 'Thiếu nhi (Dưới 12 tuổi)', 'Từ ngữ trong sáng, trực quan, tuyệt đối an toàn', selectedAge, (val) => setModalState(() => selectedAge = val), isDark),
                    _buildAgeOption('teens', 'Học sinh & Sinh viên (12 - 22 tuổi)', 'Phong cách trẻ trung, nhiệt huyết, hỗ trợ học tập', selectedAge, (val) => setModalState(() => selectedAge = val), isDark),
                    _buildAgeOption('adults', 'Người trưởng thành (23 - 55 tuổi)', 'Chuyên sâu, logic, thực tế và ứng dụng cao', selectedAge, (val) => setModalState(() => selectedAge = val), isDark),
                    _buildAgeOption('seniors', 'Người lớn tuổi (Trên 55 tuổi)', 'Kính trọng, từ tốn, ấm áp và kiên nhẫn', selectedAge, (val) => setModalState(() => selectedAge = val), isDark),
                    const SizedBox(height: 16),

                    // Response Style Selector
                    Text('Phong cách trả lời của AI:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildStyleChip('detailed', 'Chi tiết, sâu sắc', selectedStyle, (v) => setModalState(() => selectedStyle = v)),
                        const SizedBox(width: 6),
                        _buildStyleChip('balanced', 'Cân bằng', selectedStyle, (v) => setModalState(() => selectedStyle = v)),
                        const SizedBox(width: 6),
                        _buildStyleChip('concise', 'Súc tích', selectedStyle, (v) => setModalState(() => selectedStyle = v)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Preferred Pronoun
                    Text('Cách xưng hô mong muốn:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _pronouns.map((p) {
                        final isSel = selectedPronoun == p;
                        return ChoiceChip(
                          label: Text(p),
                          selected: isSel,
                          onSelected: (sel) => setModalState(() => selectedPronoun = p),
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            fontSize: 11,
                            color: isSel ? Colors.white : textSecondary,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Custom Instructions
                    Text('Ghi chú / Chỉ dẫn riêng cho AI:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: instructionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Ví dụ: Luôn chào ngắn gọn, giải thích code kèm bình luận tiếng Việt...',
                        hintStyle: TextStyle(fontSize: 12, color: textSecondary),
                        filled: true,
                        fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderColor)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    ElevatedButton(
                      onPressed: () {
                        final updated = current.copyWith(
                          name: nameController.text.trim().isEmpty ? 'Bạn' : nameController.text.trim(),
                          avatarEmoji: selectedEmoji,
                          ageGroup: selectedAge,
                          responseStyle: selectedStyle,
                          preferredPronoun: selectedPronoun,
                          customInstruction: instructionController.text.trim(),
                        );
                        context.read<ChatBloc>().add(UpdateUserProfileEvent(updated));
                        Navigator.of(sheetContext).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Lưu hồ sơ cá nhân', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAgeOption(
    String key,
    String title,
    String desc,
    String current,
    ValueChanged<String> onSelect,
    bool isDark,
  ) {
    final isSelected = key == current;
    return GestureDetector(
      onTap: () => onSelect(key),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: isSelected ? AppColors.primary : Colors.grey,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  Text(desc, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStyleChip(String key, String label, String current, ValueChanged<String> onSelect) {
    final isSelected = key == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelect(key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.withOpacity(0.4)),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.grey,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showBackupExportDialog(BuildContext context) {
    final storage = context.read<ChatBloc>().storageService;
    final jsonString = storage.exportBackupData();

    showDialog(
      context: context,
      builder: (dlgContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.backup_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Sao lưu dữ liệu JSON'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dữ liệu gồm toàn bộ lịch sử trò chuyện, ghi nhớ nhân vật và hồ sơ cá nhân đã được trích xuất thành định dạng JSON tiêu chuẩn an toàn.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            Container(
              height: 120,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: Text(
                  jsonString,
                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlgContext).pop(),
            child: const Text('Đóng'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.white),
            label: const Text('Sao chép JSON', style: TextStyle(color: Colors.white)),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonString));
              Navigator.of(dlgContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã sao chép dữ liệu sao lưu vào bộ nhớ tạm!'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showRestoreImportDialog(BuildContext context) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dlgContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.restore_page_rounded, color: AppColors.accentCyan),
            SizedBox(width: 8),
            Text('Khôi phục dữ liệu'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dán nội dung JSON đã sao lưu trước đó vào ô bên dưới để khôi phục lại toàn bộ dữ liệu ứng dụng:',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              maxLines: 5,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              decoration: const InputDecoration(
                hintText: 'Dán mã JSON sao lưu tại đây...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlgContext).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentCyan),
            icon: const Icon(Icons.download_done_rounded, size: 16, color: Colors.white),
            label: const Text('Khôi phục', style: TextStyle(color: Colors.white)),
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              final storage = context.read<ChatBloc>().storageService;
              final ok = await storage.importRestoreData(text);
              Navigator.of(dlgContext).pop();

              if (ok) {
                // Reload bloc state
                context.read<ChatBloc>().add(LoadChatHistoryEvent());
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Khôi phục dữ liệu thành công!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Lỗi: Định dạng JSON không hợp lệ hoặc dữ liệu bị hỏng.'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Hồ sơ & Cá nhân hóa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Profile Card
            BlocBuilder<ChatBloc, ChatState>(
              builder: (context, state) {
                final profile = state.userProfile;
                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.primary, AppColors.accentCyan],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(profile.avatarEmoji, style: const TextStyle(fontSize: 30)),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile.name,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  profile.ageGroupLabel,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primaryLight,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Xưng hô: ${profile.preferredPronoun} • ${profile.responseStyleLabel}',
                                  style: TextStyle(fontSize: 11, color: textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _showEditProfileSheet(context, profile),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.edit_note_rounded, size: 18, color: AppColors.primary),
                          label: const Text('Chỉnh sửa thông tin cá nhân', style: TextStyle(color: AppColors.primary)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Section: Cài đặt hệ thống & Trợ lý
            Text('Hệ thống & Trợ lý AI', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary)),
            const SizedBox(height: 10),

            _buildActionTile(
              context,
              icon: Icons.key_rounded,
              iconColor: AppColors.primary,
              title: 'Cấu hình API Key (BYOK)',
              subtitle: 'Gemini, OpenAI, Anthropic, ElevenLabs',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
              cardBg: cardBg,
              borderColor: borderColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            const SizedBox(height: 8),

            _buildActionTile(
              context,
              icon: Icons.graphic_eq_rounded,
              iconColor: AppColors.accentPink,
              title: 'Phòng thu giọng nói (Voice Studio)',
              subtitle: 'Edge-TTS, ElevenLabs, chỉnh pitch, rate & cảm xúc',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
              cardBg: cardBg,
              borderColor: borderColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            const SizedBox(height: 8),

            // Theme Toggle Tile
            BlocBuilder<SettingsBloc, SettingsState>(
              builder: (context, state) {
                final isDark = state.themeMode == ThemeMode.dark;
                return _buildActionTile(
                  context,
                  icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  iconColor: AppColors.warning,
                  title: 'Chế độ giao diện',
                  subtitle: isDark ? 'Giao diện Tối (Dark Mode)' : 'Giao diện Sáng (Light Mode)',
                  trailing: Switch(
                    value: isDark,
                    activeColor: AppColors.primary,
                    onChanged: (_) {
                      context.read<SettingsBloc>().add(ToggleThemeModeEvent());
                    },
                  ),
                  cardBg: cardBg,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                );
              },
            ),
            const SizedBox(height: 24),

            // Section: Sao lưu & Bảo toàn dữ liệu
            Text('Bảo toàn & Sao lưu dữ liệu', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary)),
            const SizedBox(height: 10),

            _buildActionTile(
              context,
              icon: Icons.backup_rounded,
              iconColor: AppColors.success,
              title: 'Sao lưu dữ liệu (Export JSON)',
              subtitle: 'Trích xuất toàn bộ lịch sử và nhân vật thành tệp JSON',
              onTap: () => _showBackupExportDialog(context),
              cardBg: cardBg,
              borderColor: borderColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            const SizedBox(height: 8),

            _buildActionTile(
              context,
              icon: Icons.restore_page_rounded,
              iconColor: AppColors.accentCyan,
              title: 'Khôi phục dữ liệu (Import JSON)',
              subtitle: 'Nhập lại dữ liệu sao lưu trước khi nâng cấp ứng dụng',
              onTap: () => _showRestoreImportDialog(context),
              cardBg: cardBg,
              borderColor: borderColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            const SizedBox(height: 24),

            // App Build & Signing Verification Card
            Container(
              width: double.infinity,
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
                      const Icon(Icons.verified_user_rounded, color: AppColors.success, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'PolyVoice AI • Phiên bản 1.1.0 (Build 7)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '✓ Release Keystore vĩnh viễn (SHA-256) đã kích hoạt.\n'
                    '✓ Hỗ trợ cập nhật cài đè trực tiếp không lỗi INSTALL_FAILED_UPDATE_INCOMPATIBLE.\n'
                    '✓ Lưu trữ cục bộ bảo toàn dữ liệu qua cơ chế Database Migration v2.',
                    style: TextStyle(fontSize: 11, color: textSecondary, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 11, color: textSecondary)),
        trailing: trailing ?? Icon(Icons.chevron_right_rounded, color: textSecondary),
        onTap: onTap,
      ),
    );
  }
}
