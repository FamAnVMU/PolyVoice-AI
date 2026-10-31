import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../services/llm/local_model_manager.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';
import '../../data/models/ai_model_info.dart';
import '../widgets/api_test_floating_banner.dart';
import '../widgets/model_selection_sheet.dart';

class ApiKeysView extends StatefulWidget {
  const ApiKeysView({super.key});

  @override
  State<ApiKeysView> createState() => _ApiKeysViewState();
}

class _ApiKeysViewState extends State<ApiKeysView> {
  int _selectedTab = 0; // 0: AI Cloud, 1: AI Local, 2: Cấu hình chung

  late TextEditingController _geminiController;
  late TextEditingController _openAiController;
  late TextEditingController _anthropicController;
  late TextEditingController _groqController;
  late TextEditingController _openRouterKeyController;
  late TextEditingController _openRouterUrlController;
  late TextEditingController _localAiBaseUrlController;
  late TextEditingController _elevenLabsKeyController;
  late TextEditingController _modelController;

  String _selectedProvider = AppConstants.providerGemini;
  String _sttMode = AppConstants.sttModeOnDevice;

  bool _obscureGemini = true;
  bool _obscureOpenAi = true;
  bool _obscureAnthropic = true;
  bool _obscureGroq = true;
  bool _obscureOpenRouter = true;
  bool _obscureElevenLabs = true;

  String? _detectedClipboardKey;
  String? _detectedClipboardProvider;

  // Hardware evaluation state
  DeviceHardwareProfile? _hardwareProfile;
  bool _isEvaluatingHardware = false;

  // Local model download state
  StreamSubscription? _downloadSub;
  final Map<String, double> _downloadProgress = {};
  final Map<String, String> _downloadStatus = {};
  final Map<String, bool> _downloadedModels = {};

  @override
  void initState() {
    super.initState();
    final state = context.read<SettingsBloc>().state;
    final keys = state.apiKeys;

    _geminiController = TextEditingController(text: keys.geminiKey);
    _openAiController = TextEditingController(text: keys.openAiKey);
    _anthropicController = TextEditingController(text: keys.anthropicKey);
    _groqController = TextEditingController(text: keys.groqKey);
    _openRouterKeyController = TextEditingController(text: keys.openRouterKey);
    _openRouterUrlController = TextEditingController(text: keys.openRouterBaseUrl);
    _localAiBaseUrlController = TextEditingController(text: keys.localAiBaseUrl);
    _elevenLabsKeyController = TextEditingController(text: state.voiceConfig.elevenLabsApiKey);
    _modelController = TextEditingController(text: keys.selectedModel);
    _selectedProvider = keys.selectedProvider;
    _sttMode = keys.sttMode;

    _checkClipboard();
    _evaluateHardware();
    _checkDownloadedModels();

    _downloadSub = LocalModelManager.instance.downloadProgressStream.listen((data) {
      if (!mounted) return;
      final modelId = data['modelId'] as String?;
      final status = data['status'] as String?;
      final progress = data['progress'] as double?;

      if (modelId != null) {
        setState(() {
          if (progress != null) _downloadProgress[modelId] = progress;
          if (status != null) _downloadStatus[modelId] = status;
          if (status == 'completed') {
            _downloadedModels[modelId] = true;
          } else if (status == 'deleted') {
            _downloadedModels[modelId] = false;
            _downloadProgress.remove(modelId);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _downloadSub?.cancel();
    _geminiController.dispose();
    _openAiController.dispose();
    _anthropicController.dispose();
    _groqController.dispose();
    _openRouterKeyController.dispose();
    _openRouterUrlController.dispose();
    _localAiBaseUrlController.dispose();
    _elevenLabsKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _checkClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isEmpty) return;

      if (text.startsWith('AIza') && text != _geminiController.text.trim()) {
        setState(() {
          _detectedClipboardKey = text;
          _detectedClipboardProvider = 'Google Gemini';
        });
      } else if (text.startsWith('sk-ant-') && text != _anthropicController.text.trim()) {
        setState(() {
          _detectedClipboardKey = text;
          _detectedClipboardProvider = 'Anthropic Claude';
        });
      } else if (text.startsWith('sk-or-') && text != _openRouterKeyController.text.trim()) {
        setState(() {
          _detectedClipboardKey = text;
          _detectedClipboardProvider = 'OpenRouter';
        });
      } else if (text.startsWith('gsk_') && text != _groqController.text.trim()) {
        setState(() {
          _detectedClipboardKey = text;
          _detectedClipboardProvider = 'Groq Cloud';
        });
      } else if (text.startsWith('sk-') && text != _openAiController.text.trim()) {
        setState(() {
          _detectedClipboardKey = text;
          _detectedClipboardProvider = 'OpenAI';
        });
      }
    } catch (_) {}
  }

  void _applyDetectedKey() {
    if (_detectedClipboardKey == null) return;
    setState(() {
      if (_detectedClipboardProvider == 'Google Gemini') {
        _geminiController.text = _detectedClipboardKey!;
      } else if (_detectedClipboardProvider == 'OpenAI') {
        _openAiController.text = _detectedClipboardKey!;
      } else if (_detectedClipboardProvider == 'Anthropic Claude') {
        _anthropicController.text = _detectedClipboardKey!;
      } else if (_detectedClipboardProvider == 'Groq Cloud') {
        _groqController.text = _detectedClipboardKey!;
      } else if (_detectedClipboardProvider == 'OpenRouter') {
        _openRouterKeyController.text = _detectedClipboardKey!;
      }
      _detectedClipboardKey = null;
      _detectedClipboardProvider = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✓ Đã dán API Key từ bộ nhớ tạm!'), backgroundColor: AppColors.success),
    );
  }

  Future<void> _evaluateHardware() async {
    setState(() => _isEvaluatingHardware = true);
    try {
      final profile = await LocalModelManager.instance.evaluateDeviceHardware();
      if (mounted) {
        setState(() {
          _hardwareProfile = profile;
          _isEvaluatingHardware = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isEvaluatingHardware = false);
    }
  }

  Future<void> _checkDownloadedModels() async {
    for (final m in LocalModelManager.catalog) {
      final isDone = await LocalModelManager.instance.isModelDownloaded(m);
      if (mounted) {
        setState(() {
          _downloadedModels[m.id] = isDone;
        });
      }
    }
  }

  void _testKey(String provider, String key, {String? model, String? baseUrl}) {
    if (key.trim().isEmpty && provider != AppConstants.providerLocal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập API Key trước khi kiểm tra.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    context.read<SettingsBloc>().add(TestApiKeyConnectionEvent(
          provider: provider,
          apiKey: key.trim(),
          model: model ?? _modelController.text.trim(),
          baseUrl: baseUrl,
        ));
  }

  void _confirmDeleteKey(String provider, String providerDisplayName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.error),
            const SizedBox(width: 8),
            Text('Xóa API Key $providerDisplayName'),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa khóa API của $providerDisplayName?\n\n'
          'Sau khi xóa, ứng dụng sẽ không thể gửi yêu cầu AI đến nhà cung cấp này cho đến khi bạn nhập khóa mới.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<SettingsBloc>().add(DeleteProviderKeyEvent(provider));
              setState(() {
                if (provider == AppConstants.providerGemini) _geminiController.clear();
                if (provider == AppConstants.providerOpenAi) _openAiController.clear();
                if (provider == AppConstants.providerAnthropic) _anthropicController.clear();
                if (provider == AppConstants.providerGroq) _groqController.clear();
                if (provider == AppConstants.providerOpenRouter) _openRouterKeyController.clear();
                if (provider == 'elevenlabs') _elevenLabsKeyController.clear();
              });
            },
            child: const Text('Xác nhận xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _saveAllKeys() {
    final state = context.read<SettingsBloc>().state;
    final updated = state.apiKeys.copyWith(
          geminiKey: _geminiController.text.trim(),
          openAiKey: _openAiController.text.trim(),
          anthropicKey: _anthropicController.text.trim(),
          groqKey: _groqController.text.trim(),
          openRouterKey: _openRouterKeyController.text.trim(),
          openRouterBaseUrl: _openRouterUrlController.text.trim(),
          localAiBaseUrl: _localAiBaseUrlController.text.trim(),
          selectedProvider: _selectedProvider,
          selectedModel: _modelController.text.trim(),
          sttMode: _sttMode,
        );

    context.read<SettingsBloc>().add(UpdateApiKeysEvent(updated));

    final updatedVoiceConfig = state.voiceConfig.copyWith(
      elevenLabsApiKey: _elevenLabsKeyController.text.trim(),
    );
    context.read<SettingsBloc>().add(UpdateVoiceConfigEvent(updatedVoiceConfig));
  }

  void _openModelPicker() async {
    final chosen = await ModelSelectionSheet.show(
      context,
      provider: _selectedProvider,
      currentModel: _modelController.text.trim(),
    );
    if (chosen != null && chosen.isNotEmpty) {
      setState(() {
        _modelController.text = chosen;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Stack(
      children: [
        Column(
          children: [
            // Segmented Top Navigation (AI Cloud | AI Local | Cấu hình chung)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  _buildTabButton(0, '☁️ AI Cloud', isDark),
                  _buildTabButton(1, '📱 AI Local', isDark),
                  _buildTabButton(2, '⚙️ Cấu hình chung', isDark),
                ],
              ),
            ),

            // Main Content Area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Clipboard Banner
                    if (_detectedClipboardKey != null) ...[
                      _buildClipboardBanner(cardBg, borderColor, textPrimary),
                      const SizedBox(height: 14),
                    ],

                    if (_selectedTab == 0) _buildCloudSection(cardBg, borderColor, textPrimary, textSecondary, isDark),
                    if (_selectedTab == 1) _buildLocalSection(cardBg, borderColor, textPrimary, textSecondary, isDark),
                    if (_selectedTab == 2) _buildConfigSection(cardBg, borderColor, textPrimary, textSecondary, isDark),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Global Floating Notification Banner (Always visible on top of screen)
        const ApiTestFloatingBanner(),
      ],
    );
  }

  Widget _buildTabButton(int index, String title, bool isDark) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClipboardBanner(Color cardBg, Color borderColor, Color textPrimary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.content_paste_go_rounded, color: AppColors.primaryLight, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Phát hiện $_detectedClipboardProvider Key trong bộ nhớ tạm',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary),
                ),
                Text(
                  '${_detectedClipboardKey!.substring(0, min(14, _detectedClipboardKey!.length))}...',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _applyDetectedKey,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Dán nhanh', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // SECTION A: AI CLOUD (Gemini, OpenAI, Claude, Groq, OpenRouter, ElevenLabs)
  // ----------------------------------------------------
  Widget _buildCloudSection(Color cardBg, Color borderColor, Color textPrimary, Color textSecondary, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Security architecture intro
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.security_rounded, color: AppColors.accentCyan, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bảo mật BYOK (Zero Server Cost)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Khóa API Key của bạn được lưu mã hóa trực tiếp trong phần cứng Keystore / Keychain. Ứng dụng kết nối thẳng đến nhà cung cấp AI, không qua máy chủ trung gian.',
                      style: TextStyle(fontSize: 11.5, color: textSecondary, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 1. Google Gemini Card
        _buildProviderCard(
          providerId: AppConstants.providerGemini,
          displayName: 'Google Gemini',
          badgeText: 'Miễn phí & Tốc độ cao',
          iconData: Icons.auto_awesome,
          accentColor: const Color(0xFF4285F4),
          controller: _geminiController,
          obscureText: _obscureGemini,
          hintText: 'AIzaSy...',
          onToggleObscure: () => setState(() => _obscureGemini = !_obscureGemini),
          defaultModel: AppConstants.defaultGeminiModel,
          cardBg: cardBg,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        ),
        const SizedBox(height: 14),

        // 2. OpenAI Card
        _buildProviderCard(
          providerId: AppConstants.providerOpenAi,
          displayName: 'OpenAI (ChatGPT API)',
          badgeText: 'GPT-4o & o3-mini',
          iconData: Icons.psychology_rounded,
          accentColor: const Color(0xFF10A37F),
          controller: _openAiController,
          obscureText: _obscureOpenAi,
          hintText: 'sk-proj-...',
          onToggleObscure: () => setState(() => _obscureOpenAi = !_obscureOpenAi),
          defaultModel: AppConstants.defaultOpenAiModel,
          cardBg: cardBg,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        ),
        const SizedBox(height: 14),

        // 3. Anthropic Claude Card
        _buildProviderCard(
          providerId: AppConstants.providerAnthropic,
          displayName: 'Anthropic Claude',
          badgeText: 'Claude 3.7 Sonnet',
          iconData: Icons.lightbulb_rounded,
          accentColor: const Color(0xFFD97706),
          controller: _anthropicController,
          obscureText: _obscureAnthropic,
          hintText: 'sk-ant-api03-...',
          onToggleObscure: () => setState(() => _obscureAnthropic = !_obscureAnthropic),
          defaultModel: AppConstants.defaultAnthropicModel,
          cardBg: cardBg,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        ),
        const SizedBox(height: 14),

        // 4. Groq Cloud Card
        _buildProviderCard(
          providerId: AppConstants.providerGroq,
          displayName: 'Groq Cloud (LPU Inference)',
          badgeText: '300+ token/s & Whisper STT',
          iconData: Icons.bolt_rounded,
          accentColor: const Color(0xFFF97316),
          controller: _groqController,
          obscureText: _obscureGroq,
          hintText: 'gsk_...',
          onToggleObscure: () => setState(() => _obscureGroq = !_obscureGroq),
          defaultModel: AppConstants.defaultGroqModel,
          cardBg: cardBg,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        ),
        const SizedBox(height: 14),

        // 5. OpenRouter & Custom Gateway Card
        _buildProviderCard(
          providerId: AppConstants.providerOpenRouter,
          displayName: 'OpenRouter / Custom AI',
          badgeText: 'DeepSeek R1, Qwen & Custom',
          iconData: Icons.hub_rounded,
          accentColor: const Color(0xFF8B5CF6),
          controller: _openRouterKeyController,
          obscureText: _obscureOpenRouter,
          hintText: 'sk-or-v1-...',
          onToggleObscure: () => setState(() => _obscureOpenRouter = !_obscureOpenRouter),
          defaultModel: AppConstants.defaultOpenRouterModel,
          customUrlController: _openRouterUrlController,
          customUrlHint: 'https://openrouter.ai/api/v1',
          cardBg: cardBg,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        ),
        const SizedBox(height: 20),

        // Separate Voice Section: ElevenLabs
        Row(
          children: [
            const Icon(Icons.record_voice_over_rounded, size: 18, color: AppColors.accentPink),
            const SizedBox(width: 8),
            Text(
              'DỊCH VỤ GIỌNG NÓI NHÂN TẠO (AI VOICE)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.accentPink.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.graphic_eq_rounded, color: AppColors.accentPink, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'ElevenLabs API Key',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _elevenLabsKeyController.text.trim().isNotEmpty
                          ? AppColors.success.withOpacity(0.15)
                          : Colors.grey.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _elevenLabsKeyController.text.trim().isNotEmpty ? 'Đã cài đặt' : 'Tùy chọn',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _elevenLabsKeyController.text.trim().isNotEmpty ? AppColors.success : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Dành riêng cho tính năng Clone giọng nói nhân vật. Mặc định ứng dụng đã tích hợp Microsoft Edge-TTS tự nhiên miễn phí 100%.',
                style: TextStyle(fontSize: 11.5, color: textSecondary, height: 1.3),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _elevenLabsKeyController,
                obscureText: _obscureElevenLabs,
                decoration: InputDecoration(
                  labelText: 'ElevenLabs API Key',
                  hintText: 'sk_...',
                  prefixIcon: const Icon(Icons.key_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureElevenLabs ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureElevenLabs = !_obscureElevenLabs),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_elevenLabsKeyController.text.trim().isNotEmpty)
                    TextButton.icon(
                      onPressed: () => _confirmDeleteKey('elevenlabs', 'ElevenLabs'),
                      icon: const Icon(Icons.delete_outline, size: 15, color: AppColors.error),
                      label: const Text('Xóa key', style: TextStyle(color: AppColors.error, fontSize: 12)),
                    ),
                  ElevatedButton.icon(
                    onPressed: _saveAllKeys,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    icon: const Icon(Icons.save_rounded, size: 15, color: Colors.white),
                    label: const Text('Lưu Voice Key', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProviderCard({
    required String providerId,
    required String displayName,
    required String badgeText,
    required IconData iconData,
    required Color accentColor,
    required TextEditingController controller,
    required bool obscureText,
    required String hintText,
    required VoidCallback onToggleObscure,
    required String defaultModel,
    TextEditingController? customUrlController,
    String? customUrlHint,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final state = context.watch<SettingsBloc>().state;
    final testStatus = state.providerTestStatus[providerId] ?? ApiTestStatus.idle;
    final testMessage = state.providerTestMessage[providerId];
    final hasKey = controller.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: testStatus == ApiTestStatus.success
              ? AppColors.success.withOpacity(0.5)
              : testStatus == ApiTestStatus.failed
                  ? AppColors.error.withOpacity(0.5)
                  : borderColor,
          width: testStatus != ApiTestStatus.idle ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Icon, Name, Configured Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, color: accentColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: textPrimary),
                    ),
                    Text(
                      badgeText,
                      style: TextStyle(fontSize: 11, color: accentColor, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasKey ? AppColors.success.withOpacity(0.15) : Colors.grey.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      hasKey ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                      size: 12,
                      color: hasKey ? AppColors.success : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasKey ? 'Đã cấu hình' : 'Chưa nhập',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: hasKey ? AppColors.success : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // API Key Input
          TextField(
            controller: controller,
            obscureText: obscureText,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: '$displayName API Key',
              hintText: hintText,
              prefixIcon: const Icon(Icons.key_rounded),
              suffixIcon: IconButton(
                icon: Icon(obscureText ? Icons.visibility : Icons.visibility_off),
                onPressed: onToggleObscure,
              ),
            ),
          ),

          // Optional Custom URL Input
          if (customUrlController != null) ...[
            const SizedBox(height: 10),
            TextField(
              controller: customUrlController,
              decoration: InputDecoration(
                labelText: 'Endpoint Base URL',
                hintText: customUrlHint ?? 'https://api.openai.com/v1',
                prefixIcon: const Icon(Icons.link_rounded),
              ),
            ),
          ],
          const SizedBox(height: 10),

          // Inline Test Status Summary (if available)
          if (testStatus != ApiTestStatus.idle && testMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: testStatus == ApiTestStatus.success
                    ? AppColors.success.withOpacity(0.12)
                    : testStatus == ApiTestStatus.failed
                        ? AppColors.error.withOpacity(0.12)
                        : AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    testStatus == ApiTestStatus.success
                        ? Icons.check_circle_rounded
                        : testStatus == ApiTestStatus.failed
                            ? Icons.error_rounded
                            : Icons.sync_rounded,
                    size: 14,
                    color: testStatus == ApiTestStatus.success
                        ? AppColors.success
                        : testStatus == ApiTestStatus.failed
                            ? AppColors.error
                            : AppColors.primaryLight,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      testMessage,
                      style: TextStyle(
                        fontSize: 11,
                        color: testStatus == ApiTestStatus.success
                            ? AppColors.success
                            : testStatus == ApiTestStatus.failed
                                ? AppColors.error
                                : textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Actions Row: Delete, Test Connection, Save
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (hasKey)
                TextButton.icon(
                  onPressed: () => _confirmDeleteKey(providerId, displayName),
                  icon: const Icon(Icons.delete_outline_rounded, size: 15, color: AppColors.error),
                  label: const Text('Xóa', style: TextStyle(color: AppColors.error, fontSize: 12)),
                )
              else
                const SizedBox.shrink(),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _testKey(
                      providerId,
                      controller.text,
                      model: defaultModel,
                      baseUrl: customUrlController?.text,
                    ),
                    icon: testStatus == ApiTestStatus.testing
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_tethering_rounded, size: 14),
                    label: const Text('Kiểm tra kết nối', style: TextStyle(fontSize: 11.5)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saveAllKeys,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Lưu', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // SECTION B: AI LOCAL (Hardware Check, Model Download, Ollama / Local Daemon)
  // ----------------------------------------------------
  Widget _buildLocalSection(Color cardBg, Color borderColor, Color textPrimary, Color textSecondary, bool isDark) {
    final profile = _hardwareProfile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Privacy Banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.success.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_rounded, color: AppColors.success, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '100% Quyền riêng tư & Hoạt động Offline',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'AI Local chạy mô hình ngay trên vi xử lý thiết bị của bạn hoặc máy chủ nội bộ LAN. Không có bất kỳ dữ liệu nào được gửi ra ngoài Internet.',
                      style: TextStyle(fontSize: 11.5, color: textSecondary, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Hardware Capability Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.memory_rounded, color: AppColors.accentCyan, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Đánh giá phần cứng thiết bị',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: _isEvaluatingHardware
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh_rounded, size: 20),
                    tooltip: 'Quét lại phần cứng',
                    onPressed: _evaluateHardware,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (profile != null) ...[
                // Tier badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: profile.tier == DeviceAiTier.incompatible
                        ? AppColors.warning.withOpacity(0.18)
                        : AppColors.accentCyan.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    profile.tierLabel,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: profile.tier == DeviceAiTier.incompatible ? AppColors.warning : AppColors.accentCyan,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Specs Grid
                Row(
                  children: [
                    _buildSpecTile('Tổng RAM', '${profile.totalRamGb} GB', Icons.storage_rounded, textPrimary, textSecondary),
                    _buildSpecTile('RAM khả dụng', '${profile.availableRamGb} GB', Icons.speed_rounded, textPrimary, textSecondary),
                    _buildSpecTile('Số nhân CPU', '${profile.cpuCores} Cores', Icons.developer_board_rounded, textPrimary, textSecondary),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  profile.recommendation,
                  style: TextStyle(fontSize: 12, color: textSecondary, height: 1.35),
                ),
              ] else ...[
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Local Daemon Connection (Ollama / LocalAI)
        Text(
          'KẾT NỐI LOCAL AI DAEMON (OLLAMA / LOCAL SERVER)',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: textSecondary),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kết nối đến Ollama hoặc LM Studio đang chạy trên thiết bị hoặc máy tính cùng mạng WiFi (LAN):',
                style: TextStyle(fontSize: 12, color: textSecondary),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _localAiBaseUrlController,
                decoration: const InputDecoration(
                  labelText: 'Local Endpoint URL',
                  hintText: 'http://127.0.0.1:11434 hoặc http://192.168.1.x:11434',
                  prefixIcon: Icon(Icons.lan_rounded),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _testKey(
                      AppConstants.providerLocal,
                      '',
                      baseUrl: _localAiBaseUrlController.text.trim(),
                    ),
                    icon: const Icon(Icons.wifi_tethering_rounded, size: 14),
                    label: const Text('Kiểm tra kết nối Daemon', style: TextStyle(fontSize: 11.5)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saveAllKeys,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    child: const Text('Lưu Endpoint', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // On-Device Model Catalog
        Text(
          'MÔ HÌNH ON-DEVICE GGUF TƯƠNG THÍCH',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: textSecondary),
        ),
        const SizedBox(height: 10),

        ...LocalModelManager.catalog.map((model) {
          final isDownloaded = _downloadedModels[model.id] == true;
          final isDownloading = _downloadStatus[model.id] == 'downloading';
          final progress = _downloadProgress[model.id] ?? 0.0;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDownloaded ? AppColors.success.withOpacity(0.5) : borderColor,
                width: isDownloaded ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        model.name,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDownloaded
                            ? AppColors.success.withOpacity(0.18)
                            : AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isDownloaded ? 'Đã tải về' : '${model.downloadSizeMb.toInt()} MB • ${model.format}',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: isDownloaded ? AppColors.success : AppColors.primaryLight,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  model.description,
                  style: TextStyle(fontSize: 11.5, color: textSecondary, height: 1.3),
                ),
                const SizedBox(height: 8),

                // Download Progress Bar
                if (isDownloading) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.grey.withOpacity(0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Đang tải: ${(progress * 100).toInt()}%',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                      ),
                      TextButton(
                        onPressed: () {
                          LocalModelManager.instance.cancelDownload();
                          setState(() {
                            _downloadStatus[model.id] = 'cancelled';
                          });
                        },
                        child: const Text('Hủy', style: TextStyle(color: AppColors.error, fontSize: 11)),
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Yêu cầu RAM tối thiểu: ${model.requiredRamGb} GB',
                        style: TextStyle(fontSize: 11, color: textSecondary, fontWeight: FontWeight.w500),
                      ),
                      if (isDownloaded)
                        TextButton.icon(
                          onPressed: () async {
                            final success = await LocalModelManager.instance.deleteModel(model);
                            if (success && mounted) {
                              setState(() => _downloadedModels[model.id] = false);
                            }
                          },
                          icon: const Icon(Icons.delete_outline_rounded, size: 15, color: AppColors.error),
                          label: const Text('Xóa file', style: TextStyle(color: AppColors.error, fontSize: 11.5)),
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: () {
                            LocalModelManager.instance.downloadModel(model);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary.withOpacity(0.18),
                            foregroundColor: AppColors.primaryLight,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                          icon: const Icon(Icons.download_rounded, size: 14),
                          label: const Text('Tải về', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSpecTile(String label, String value, IconData icon, Color textPrimary, Color textSecondary) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: AppColors.primaryLight),
            const SizedBox(height: 3),
            Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary)),
            Text(label, style: TextStyle(fontSize: 10, color: textSecondary)),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // SECTION C: USAGE CONFIGURATION (Default Provider, Model, STT Mode)
  // ----------------------------------------------------
  Widget _buildConfigSection(Color cardBg, Color borderColor, Color textPrimary, Color textSecondary, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NHÀ CUNG CẤP AI HOẠT ĐỘNG (ACTIVE PROVIDER)',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: textSecondary),
        ),
        const SizedBox(height: 10),

        // Provider Selector Chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildProviderChoiceChip('gemini', 'Google Gemini', Icons.auto_awesome),
            _buildProviderChoiceChip('openai', 'OpenAI', Icons.psychology_rounded),
            _buildProviderChoiceChip('anthropic', 'Anthropic Claude', Icons.lightbulb_rounded),
            _buildProviderChoiceChip('groq', 'Groq Cloud', Icons.bolt_rounded),
            _buildProviderChoiceChip('openrouter', 'OpenRouter', Icons.hub_rounded),
            _buildProviderChoiceChip('local', 'AI Local', Icons.memory_rounded),
          ],
        ),
        const SizedBox(height: 22),

        // Model Selection for active provider
        Text(
          'MÔ HÌNH AI ĐANG SỬ DỤNG (ACTIVE MODEL)',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: textSecondary),
        ),
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _modelController.text.trim().isNotEmpty
                              ? _modelController.text.trim()
                              : 'Chưa chọn mô hình',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Mô hình dùng cho toàn bộ phiên trò chuyện và đàm thoại giọng nói.',
                          style: TextStyle(fontSize: 11.5, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _openModelPicker,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.tune_rounded, size: 14, color: Colors.white),
                    label: const Text('Đổi model', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // Speech-to-Text Mode Selection
        Text(
          'CHẾ ĐỘ NHẬN DIỆN GIỌNG NÓI (SPEECH-TO-TEXT)',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: textSecondary),
        ),
        const SizedBox(height: 10),

        RadioListTile<String>(
          title: const Text('Native On-Device STT (Khuyên dùng)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
          subtitle: const Text('Miễn phí 100%, xử lý offline trực tiếp trên thiết bị, độ trễ tức thì.', style: TextStyle(fontSize: 12)),
          value: AppConstants.sttModeOnDevice,
          groupValue: _sttMode,
          onChanged: (val) => setState(() => _sttMode = val!),
        ),
        RadioListTile<String>(
          title: const Text('Groq Whisper API (whisper-large-v3)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
          subtitle: const Text('Độ chính xác nhận diện đa ngôn ngữ siêu cao thông qua API Groq.', style: TextStyle(fontSize: 12)),
          value: AppConstants.sttModeGroqWhisper,
          groupValue: _sttMode,
          onChanged: (val) => setState(() => _sttMode = val!),
        ),
        const SizedBox(height: 24),

        // Save All Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _saveAllKeys,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
            ),
            icon: const Icon(Icons.check_rounded, color: Colors.white),
            label: const Text('Lưu toàn bộ cấu hình', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildProviderChoiceChip(String providerId, String label, IconData icon) {
    final isSelected = _selectedProvider == providerId;
    return ChoiceChip(
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : AppColors.primaryLight),
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedProvider = providerId;
            _modelController.text = AiModelCatalog.getDefaultModelForProvider(providerId);
          });
        }
      },
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : null,
      ),
    );
  }
}
