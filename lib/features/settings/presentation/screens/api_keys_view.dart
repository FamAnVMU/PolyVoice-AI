import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';

class ApiKeysView extends StatefulWidget {
  const ApiKeysView({super.key});

  @override
  State<ApiKeysView> createState() => _ApiKeysViewState();
}

class _ApiKeysViewState extends State<ApiKeysView> {
  late TextEditingController _geminiController;
  late TextEditingController _groqController;
  late TextEditingController _openRouterKeyController;
  late TextEditingController _openRouterUrlController;
  late TextEditingController _elevenLabsKeyController;
  late TextEditingController _modelController;

  String _selectedProvider = AppConstants.providerGemini;
  String _sttMode = AppConstants.sttModeOnDevice;

  bool _obscureGemini = true;
  bool _obscureGroq = true;
  bool _obscureOpenRouter = true;
  bool _obscureElevenLabs = true;

  String? _detectedClipboardKey;
  String? _detectedClipboardProvider;

  @override
  void initState() {
    super.initState();
    final state = context.read<SettingsBloc>().state;
    final keys = state.apiKeys;
    _geminiController = TextEditingController(text: keys.geminiKey);
    _groqController = TextEditingController(text: keys.groqKey);
    _openRouterKeyController = TextEditingController(text: keys.openRouterKey);
    _openRouterUrlController = TextEditingController(text: keys.openRouterBaseUrl);
    _elevenLabsKeyController = TextEditingController(text: state.voiceConfig.elevenLabsApiKey);
    _modelController = TextEditingController(text: keys.selectedModel);
    _selectedProvider = keys.selectedProvider;
    _sttMode = keys.sttMode;

    _checkClipboard();
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
      } else if (text.startsWith('gsk_') && text != _groqController.text.trim()) {
        setState(() {
          _detectedClipboardKey = text;
          _detectedClipboardProvider = 'Groq Cloud';
        });
      } else if (text.startsWith('sk-or-') && text != _openRouterKeyController.text.trim()) {
        setState(() {
          _detectedClipboardKey = text;
          _detectedClipboardProvider = 'OpenRouter';
        });
      }
    } catch (_) {}
  }

  void _applyDetectedKey() {
    if (_detectedClipboardKey == null) return;
    setState(() {
      if (_detectedClipboardProvider == 'Google Gemini') {
        _geminiController.text = _detectedClipboardKey!;
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

  void _testSpecificKey(String provider, String key, {String? model, String? baseUrl}) {
    if (key.trim().isEmpty) {
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
      model: model,
      baseUrl: baseUrl,
    ));
  }

  @override
  void dispose() {
    _geminiController.dispose();
    _groqController.dispose();
    _openRouterKeyController.dispose();
    _openRouterUrlController.dispose();
    _elevenLabsKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  void _saveKeys() {
    final state = context.read<SettingsBloc>().state;
    final updated = state.apiKeys.copyWith(
          geminiKey: _geminiController.text.trim(),
          groqKey: _groqController.text.trim(),
          openRouterKey: _openRouterKeyController.text.trim(),
          openRouterBaseUrl: _openRouterUrlController.text.trim(),
          selectedProvider: _selectedProvider,
          selectedModel: _modelController.text.trim(),
          sttMode: _sttMode,
        );

    context.read<SettingsBloc>().add(UpdateApiKeysEvent(updated));

    final updatedVoiceConfig = state.voiceConfig.copyWith(
      elevenLabsApiKey: _elevenLabsKeyController.text.trim(),
    );
    context.read<SettingsBloc>().add(UpdateVoiceConfigEvent(updatedVoiceConfig));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ API credentials saved securely!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _testCurrentProvider() {
    String apiKey = '';
    String? baseUrl;

    if (_selectedProvider == AppConstants.providerGemini) {
      apiKey = _geminiController.text.trim();
    } else if (_selectedProvider == AppConstants.providerGroq) {
      apiKey = _groqController.text.trim();
    } else {
      apiKey = _openRouterKeyController.text.trim();
      baseUrl = _openRouterUrlController.text.trim();
    }

    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an API Key first to test.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    context.read<SettingsBloc>().add(TestApiKeyConnectionEvent(
          provider: _selectedProvider,
          apiKey: apiKey,
          model: _modelController.text.trim(),
          baseUrl: baseUrl,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // BYOK Hero Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.15),
                      AppColors.accentCyan.withValues(alpha: 0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.vpn_key_rounded, color: AppColors.accentCyan, size: 32),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'BYOK Architecture (Zero Server Cost)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Your API keys are stored locally on device and encrypted with Keystore / Keychain. Never sent to any third-party backend.',
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
                'ACTIVE LLM PROVIDER',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.grey),
              ),
              const SizedBox(height: 10),

              // Provider Segmented Buttons
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: AppConstants.providerGemini,
                    label: Text('Gemini'),
                    icon: Icon(Icons.auto_awesome),
                  ),
                  ButtonSegment(
                    value: AppConstants.providerGroq,
                    label: Text('Groq'),
                    icon: Icon(Icons.bolt),
                  ),
                  ButtonSegment(
                    value: AppConstants.providerOpenRouter,
                    label: Text('OpenRouter'),
                    icon: Icon(Icons.hub),
                  ),
                ],
                selected: {_selectedProvider},
                onSelectionChanged: (newSelection) {
                  setState(() {
                    _selectedProvider = newSelection.first;
                    if (_selectedProvider == AppConstants.providerGemini) {
                      _modelController.text = AppConstants.defaultGeminiModel;
                    } else if (_selectedProvider == AppConstants.providerGroq) {
                      _modelController.text = AppConstants.defaultGroqModel;
                    } else {
                      _modelController.text = AppConstants.defaultOpenRouterModel;
                    }
                  });
                },
              ),

              const SizedBox(height: 24),
              const Text(
                'MODEL SELECTION',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _modelController,
                decoration: const InputDecoration(
                  labelText: 'Model Identifier',
                  hintText: 'e.g., gemini-1.5-flash, llama-3.3-70b-versatile',
                  prefixIcon: Icon(Icons.tune),
                ),
              ),

              const SizedBox(height: 24),
              const Text(
                'SPEECH-TO-TEXT (STT) MODE',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.grey),
              ),
              const SizedBox(height: 8),

              RadioListTile<String>(
                title: const Text('Mode A: Native On-Device STT'),
                subtitle: const Text('Completely free, offline speech-to-text with zero token cost.'),
                value: AppConstants.sttModeOnDevice,
                groupValue: _sttMode,
                onChanged: (val) => setState(() => _sttMode = val!),
              ),
              RadioListTile<String>(
                title: const Text('Mode B: Groq Whisper API (whisper-large-v3)'),
                subtitle: const Text('Ultra-high accuracy multilingual transcription using free Groq key.'),
                value: AppConstants.sttModeGroqWhisper,
                groupValue: _sttMode,
                onChanged: (val) => setState(() => _sttMode = val!),
              ),

              const SizedBox(height: 24),
              const Text(
                'API KEYS',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.grey),
              ),
              const SizedBox(height: 10),

              // Clipboard Auto-Detection Banner (TASK 5)
              if (_detectedClipboardKey != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
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
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
                ),
                const SizedBox(height: 14),
              ],

              // Gemini Input
              TextField(
                controller: _geminiController,
                obscureText: _obscureGemini,
                decoration: InputDecoration(
                  labelText: 'Google Gemini API Key',
                  hintText: 'AIzaSy...',
                  prefixIcon: const Icon(Icons.token),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureGemini ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureGemini = !_obscureGemini),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _testSpecificKey('gemini', _geminiController.text, model: _modelController.text),
                  icon: const Icon(Icons.wifi_tethering_rounded, size: 14),
                  label: const Text('Kiểm tra kết nối Gemini', style: TextStyle(fontSize: 11)),
                ),
              ),
              const SizedBox(height: 8),

              // Groq Input
              TextField(
                controller: _groqController,
                obscureText: _obscureGroq,
                decoration: InputDecoration(
                  labelText: 'Groq Cloud API Key',
                  hintText: 'gsk_...',
                  prefixIcon: const Icon(Icons.bolt),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureGroq ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureGroq = !_obscureGroq),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _testSpecificKey('groq', _groqController.text, model: _modelController.text),
                  icon: const Icon(Icons.wifi_tethering_rounded, size: 14),
                  label: const Text('Kiểm tra kết nối Groq', style: TextStyle(fontSize: 11)),
                ),
              ),
              const SizedBox(height: 8),

              // OpenRouter Input
              TextField(
                controller: _openRouterKeyController,
                obscureText: _obscureOpenRouter,
                decoration: InputDecoration(
                  labelText: 'OpenRouter / OpenAI-Compatible Key',
                  hintText: 'sk-or-v1-...',
                  prefixIcon: const Icon(Icons.key),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureOpenRouter ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureOpenRouter = !_obscureOpenRouter),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _testSpecificKey('openrouter', _openRouterKeyController.text, model: _modelController.text, baseUrl: _openRouterUrlController.text),
                  icon: const Icon(Icons.wifi_tethering_rounded, size: 14),
                  label: const Text('Kiểm tra kết nối OpenRouter', style: TextStyle(fontSize: 11)),
                ),
              ),
              const SizedBox(height: 8),

              TextField(
                controller: _openRouterUrlController,
                decoration: const InputDecoration(
                  labelText: 'Custom Base URL (Optional)',
                  hintText: 'https://openrouter.ai/api/v1',
                  prefixIcon: Icon(Icons.link),
                ),
              ),
              const SizedBox(height: 14),

              // ElevenLabs Input (Voice Cloning & Human-like Voice)
              TextField(
                controller: _elevenLabsKeyController,
                obscureText: _obscureElevenLabs,
                decoration: InputDecoration(
                  labelText: 'ElevenLabs API Key (Tùy chọn - Clone giọng)',
                  hintText: 'sk_...',
                  helperText: 'Tùy chọn. Nếu để trống, ứng dụng tự động kích hoạt Edge-TTS Neural miễn phí 100%.',
                  helperMaxLines: 2,
                  prefixIcon: const Icon(Icons.record_voice_over),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureElevenLabs ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureElevenLabs = !_obscureElevenLabs),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Edge-TTS Banner Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.accentCyan.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.accentCyan.withOpacity(0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified, color: AppColors.accentCyan, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Microsoft Edge-TTS đã sẵn sàng: Miễn phí vĩnh viễn, giọng Hoài My & Nam Minh chuẩn MC truyền hình.',
                        style: TextStyle(fontSize: 11.5, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Test Connection Status Banner
              if (state.testStatus != ApiTestStatus.idle) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: state.testStatus == ApiTestStatus.success
                        ? AppColors.success.withValues(alpha: 0.15)
                        : state.testStatus == ApiTestStatus.failed
                            ? AppColors.error.withValues(alpha: 0.15)
                            : AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      if (state.testStatus == ApiTestStatus.testing)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else if (state.testStatus == ApiTestStatus.success)
                        const Icon(Icons.check_circle, color: AppColors.success, size: 20)
                      else
                        const Icon(Icons.error, color: AppColors.error, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          state.testResultMessage ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: state.testStatus == ApiTestStatus.success
                                ? AppColors.success
                                : state.testStatus == ApiTestStatus.failed
                                    ? AppColors.error
                                    : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _testCurrentProvider,
                      icon: const Icon(Icons.network_check),
                      label: const Text('Test Connection'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saveKeys,
                      icon: const Icon(Icons.save),
                      label: const Text('Save & Apply'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }
}
