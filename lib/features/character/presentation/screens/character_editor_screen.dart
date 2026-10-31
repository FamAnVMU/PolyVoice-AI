import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../chat/presentation/bloc/chat_bloc.dart';
import '../../../chat/presentation/bloc/chat_event.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../voice/data/models/voice_configuration.dart';
import '../../../voice/data/models/voice_model.dart';
import '../../../voice/data/preset_voices.dart';
import '../models/ai_character_model.dart';

class CharacterEditorScreen extends StatefulWidget {
  final AICharacterModel? baseCharacter;
  final AICharacterModel? editingCharacter;

  const CharacterEditorScreen({
    super.key,
    this.baseCharacter,
    this.editingCharacter,
  });

  bool get isCustomizingBase => baseCharacter != null;
  bool get isEditingExisting => editingCharacter != null && editingCharacter!.isCustom;

  @override
  State<CharacterEditorScreen> createState() => _CharacterEditorScreenState();
}

class _CharacterEditorScreenState extends State<CharacterEditorScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _shortDescController;
  late TextEditingController _detailedBioController;
  late TextEditingController _greetingController;
  late TextEditingController _customPersonalityController;
  late TextEditingController _pronounController;

  late String _avatar;
  late String _category;
  late String _gender;
  late String _selectedVoiceId;
  late double _speed;
  late double _pitch;
  late String _speakingStyle;

  bool _isPlayingPreview = false;

  final List<String> _emojiChoices = [
    '🌸', '⚡', '🌿', '🏃', '📚', '📐', '🔬', '🌐', '💻', '📈',
    '💡', '👔', '📖', '⚔️', '🎤', '🕊️', '🌟', '🐱', '☕', '🧠',
  ];

  final List<String> _personalityTraits = [
    'Thân thiện, ấm áp',
    'Hài hước, dí dỏm',
    'Lạnh lùng, bí ẩn',
    'Dịu dàng, biết lắng nghe',
    'Nghiêm túc, chuẩn mực',
    'Thông minh, sắc sảo',
    'Năng động, thể thao',
    'Hướng nội, sâu sắc',
    'Trầm tĩnh, điềm đạm',
    'Thực tế, dứt khoát',
  ];

  final List<String> _presetPronouns = [
    'Bạn - Mình',
    'Em - Anh/Chị',
    'Tôi - Bạn',
    'Bác - Cháu',
    'Thầy - Em',
    'Bro - Mình',
  ];

  @override
  void initState() {
    super.initState();

    final target = widget.editingCharacter ?? widget.baseCharacter;

    if (widget.isCustomizingBase && widget.baseCharacter != null) {
      // Mode 1: Clone from Base Character
      final base = widget.baseCharacter!;
      _nameController = TextEditingController(text: '${base.name} (Bản tùy chỉnh)');
      _shortDescController = TextEditingController(text: base.shortDescription);
      _detailedBioController = TextEditingController(text: base.detailedBio);
      _greetingController = TextEditingController(text: base.sampleGreeting);
      _customPersonalityController = TextEditingController();
      _pronounController = TextEditingController(text: 'Mặc định theo nhân vật');

      _avatar = base.avatar;
      _category = base.category;
      _gender = base.gender;
      _selectedVoiceId = base.voiceConfig.voiceId;
      _speed = base.voiceConfig.speed;
      _pitch = base.voiceConfig.pitch;
      _speakingStyle = base.speakingStyle;
    } else if (widget.isEditingExisting && widget.editingCharacter != null) {
      // Edit existing custom character
      final c = widget.editingCharacter!;
      _nameController = TextEditingController(text: c.name);
      _shortDescController = TextEditingController(text: c.shortDescription);
      _detailedBioController = TextEditingController(text: c.detailedBio);
      _greetingController = TextEditingController(text: c.sampleGreeting);
      _customPersonalityController = TextEditingController();
      _pronounController = TextEditingController();

      _avatar = c.avatar;
      _category = c.category;
      _gender = c.gender;
      _selectedVoiceId = c.voiceConfig.voiceId;
      _speed = c.voiceConfig.speed;
      _pitch = c.voiceConfig.pitch;
      _speakingStyle = c.speakingStyle;
    } else {
      // Mode 2: Create completely new character from scratch
      _nameController = TextEditingController();
      _shortDescController = TextEditingController();
      _detailedBioController = TextEditingController();
      _greetingController = TextEditingController(text: 'Xin chào! Rất vui được gặp bạn hôm nay.');
      _customPersonalityController = TextEditingController();
      _pronounController = TextEditingController(text: 'Bạn - Mình');

      _avatar = '🌟';
      _category = 'friends';
      _gender = 'female';
      _selectedVoiceId = 'preset_khanh_linh';
      _speed = 1.0;
      _pitch = 1.0;
      _speakingStyle = 'Thân thiện, ấm áp';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _shortDescController.dispose();
    _detailedBioController.dispose();
    _greetingController.dispose();
    _customPersonalityController.dispose();
    _pronounController.dispose();
    super.dispose();
  }

  List<VoiceModel> _getAvailableVoicesForGender() {
    return PresetVoices.getVoicesByGender(_gender);
  }

  Future<void> _previewSelectedVoice() async {
    final tts = context.read<SettingsBloc>().ttsService;
    if (_isPlayingTest) {
      await tts.stop();
      setState(() => _isPlayingTest = false);
      return;
    }

    setState(() => _isPlayingTest = true);

    try {
      final sampleText = _greetingController.text.trim().isNotEmpty
          ? _greetingController.text.trim()
          : 'Xin chào bạn! Đây là giọng nói thử nghiệm của tôi.';

      final voiceConfig = VoiceConfiguration(
        voiceConfigId: 'cfg_preview_${DateTime.now().millisecondsSinceEpoch}',
        voiceId: _selectedVoiceId,
        voiceName: _nameController.text.trim(),
        gender: _gender,
        speed: _speed,
        pitch: _pitch,
      );

      final settings = context.read<SettingsBloc>().state;
      await tts.stop();
      await tts.speak(
        sampleText,
        config: settings.voiceConfig,
        voiceConfig: voiceConfig,
        geminiApiKey: settings.apiKeys.geminiKey,
      );
    } finally {
      if (mounted) setState(() => _isPlayingTest = false);
    }
  }

  bool _isPlayingTest = false;

  void _saveCharacter() {
    if (!_formKey.currentState!.validate()) return;

    final String name = _nameController.text.trim();
    final String greeting = _greetingController.text.trim();
    final String shortDesc = _shortDescController.text.trim();
    final String bio = _detailedBioController.text.trim();

    // 1. Build dedicated VoiceConfiguration
    final voicePreset = PresetVoices.findVoiceSafe(_selectedVoiceId, fallbackGender: _gender);
    final voiceConfig = VoiceConfiguration(
      voiceConfigId: 'cfg_${DateTime.now().millisecondsSinceEpoch}',
      providerId: voicePreset.engineType,
      voiceId: voicePreset.id,
      voiceName: voicePreset.name,
      languageCode: 'vi-VN',
      gender: _gender,
      speakingStyle: _speakingStyle,
      speed: _speed,
      pitch: _pitch,
      isAvailable: true,
      edgeVoiceName: voicePreset.edgeVoiceName,
      remoteVoiceId: voicePreset.remoteVoiceId,
      nativeSystemVoiceName: voicePreset.nativeSystemVoiceName,
    );

    AICharacterModel characterToSave;

    if (widget.isCustomizingBase && widget.baseCharacter != null) {
      // MODE 1: Base Character customization
      // System prompt and core identity are 100% PRESERVED
      final base = widget.baseCharacter!;
      characterToSave = base.copyWith(
        id: widget.editingCharacter?.id ?? 'custom_clone_${base.id}_${const Uuid().v4().substring(0, 8)}',
        name: name,
        avatar: _avatar,
        shortDescription: shortDesc.isNotEmpty ? shortDesc : base.shortDescription,
        voiceConfig: voiceConfig,
        speakingStyle: _speakingStyle,
        isCustom: true,
        baseCharacterId: base.id,
        createdAt: widget.editingCharacter?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } else {
      // MODE 2: New Character created from scratch
      final pronoun = _pronounController.text.trim();
      final personalityText = _customPersonalityController.text.trim().isNotEmpty
          ? _customPersonalityController.text.trim()
          : _speakingStyle;

      final generatedPrompt = '''Bạn là $name - một nhân vật AI mang tính cách: $personalityText.
- Tiểu sử & vai trò: $bio
- Cách xưng hô: Luôn xưng hô theo phong cách "$pronoun" khi trò chuyện cùng người dùng.
- Phong cách giao tiếp: $_speakingStyle. Trả lời tự nhiên, có cảm xúc, giữ vững bản sắc của bạn trong suốt cuộc hội thoại.
- Ngôn ngữ: Luôn trả lời bằng tiếng Việt tự nhiên, chuẩn mực.''';

      characterToSave = AICharacterModel(
        id: widget.editingCharacter?.id ?? 'custom_char_${const Uuid().v4().substring(0, 8)}',
        name: name,
        avatar: _avatar,
        category: _category,
        shortDescription: shortDesc,
        detailedBio: bio,
        sampleGreeting: greeting,
        systemPrompt: widget.editingCharacter?.systemPrompt ?? generatedPrompt,
        voiceConfig: voiceConfig,
        speakingStyle: _speakingStyle,
        gender: _gender,
        ageSuitability: 'all',
        tags: [name, _categoryLabel(_category), _gender == 'male' ? 'Nam' : 'Nữ'],
        isFeatured: false,
        isCustom: true,
        baseCharacterId: null,
        createdAt: widget.editingCharacter?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    // Save into ChatBloc persistent storage
    context.read<ChatBloc>().add(SaveCustomCharacterEvent(characterToSave));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã lưu nhân vật "${characterToSave.name}" thành công!'),
        backgroundColor: AppColors.success,
      ),
    );

    // Show option to start chatting immediately
    Navigator.of(context).pop();
    _promptStartChat(characterToSave);
  }

  void _promptStartChat(AICharacterModel character) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Bắt đầu trò chuyện với ${character.name}?',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Cuộc trò chuyện mới sẽ được thiết lập với giọng nói và tính cách riêng của nhân vật này.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Để sau'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.read<ChatBloc>().add(CreateSessionWithCharacterEvent(character));
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ChatScreen()),
                        );
                      },
                      child: const Text('Trò chuyện ngay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _categoryLabel(String key) {
    switch (key) {
      case 'education':
        return 'Học tập & Ngoại ngữ';
      case 'experts':
        return 'Chuyên gia & Công nghệ';
      case 'entertainment':
        return 'Giải trí & Nhập vai';
      case 'emotional_support':
        return 'Tâm sự & Chữa lành';
      case 'friends':
      default:
        return 'Bạn bè & Đời sống';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final availableVoices = _getAvailableVoicesForGender();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          widget.isCustomizingBase
              ? 'Tùy chỉnh: ${widget.baseCharacter?.name}'
              : (widget.isEditingExisting ? 'Chỉnh sửa nhân vật' : 'Tạo nhân vật AI mới'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          TextButton(
            onPressed: _saveCharacter,
            child: const Text('LƯU', style: TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // MODE 1 NOTICE BANNER
              if (widget.isCustomizingBase && widget.baseCharacter != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.verified_user_rounded, color: AppColors.primaryLight, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Đặc tính gốc được bảo toàn',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryLight),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Bạn đang tạo một phiên bản tùy chỉnh giọng nói và tên gọi từ nhân vật gốc "${widget.baseCharacter!.name}". Tính cách, kiến thức và prompt gốc sẽ được giữ nguyên vẹn.',
                              style: TextStyle(fontSize: 12, color: textPrimary, height: 1.35),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // SECTION 1: IDENTITY & AVATAR
              Text('THÔNG TIN NHÂN VẬT',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary)),
              const SizedBox(height: 12),

              Row(
                children: [
                  GestureDetector(
                    onTap: () => _showAvatarPicker(context),
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.accentCyan]),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(_avatar, style: const TextStyle(fontSize: 32)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Tên nhân vật *',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập tên' : null,
                        ),
                        const SizedBox(height: 6),
                        Text('Nhấn vào biểu tượng tròn để đổi avatar', style: TextStyle(fontSize: 11, color: textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Short Description
              TextFormField(
                controller: _shortDescController,
                decoration: const InputDecoration(
                  labelText: 'Mô tả ngắn',
                  hintText: 'Ví dụ: Người bạn vui tính, thích du lịch...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Detailed Bio / Background
              if (!widget.isCustomizingBase) ...[
                TextFormField(
                  controller: _detailedBioController,
                  decoration: const InputDecoration(
                    labelText: 'Tiểu sử & Câu chuyện của nhân vật',
                    hintText: 'Nhập xuất thân, sở thích, thế mạnh của nhân vật...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
              ],

              // Greeting
              TextFormField(
                controller: _greetingController,
                decoration: const InputDecoration(
                  labelText: 'Lời chào mẫu khi bắt đầu chat',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              // SECTION 2: GENDER & VOICE CONFIGURATION
              Text('CẤU HÌNH GIỌNG NÓI RIÊNG BIỆT',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary)),
              const SizedBox(height: 12),

              // Gender Selector (Locked if customizing base character to preserve consistency)
              if (!widget.isCustomizingBase) ...[
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Giọng Nữ'),
                        value: 'female',
                        groupValue: _gender,
                        activeColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: borderColor),
                        ),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _gender = val;
                              _selectedVoiceId = 'preset_khanh_linh';
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Giọng Nam'),
                        value: 'male',
                        groupValue: _gender,
                        activeColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: borderColor),
                        ),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _gender = val;
                              _selectedVoiceId = 'preset_minh_an';
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],

              // Voice Selection Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: availableVoices.any((v) => v.id == _selectedVoiceId)
                        ? _selectedVoiceId
                        : availableVoices.first.id,
                    isExpanded: true,
                    items: availableVoices.map((voice) {
                      return DropdownMenuItem<String>(
                        value: voice.id,
                        child: Row(
                          children: [
                            Icon(
                              voice.gender == 'male' ? Icons.male_rounded : Icons.female_rounded,
                              size: 18,
                              color: voice.gender == 'male' ? Colors.blue : Colors.pink,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${voice.name} (${voice.description.split(':').first.trim()})',
                                style: TextStyle(fontSize: 13, color: textPrimary, fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (newId) {
                      if (newId != null) {
                        setState(() {
                          _selectedVoiceId = newId;
                          final v = PresetVoices.findById(newId);
                          _speed = v.defaultSpeed;
                          _pitch = v.defaultPitch;
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Pacing & Pitch Sliders
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
                        Text('Tốc độ đọc: ${_speed.toStringAsFixed(2)}x',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
                        TextButton(
                          onPressed: () => setState(() => _speed = 1.0),
                          child: const Text('Mặc định', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                    Slider(
                      value: _speed,
                      min: 0.7,
                      max: 1.3,
                      divisions: 12,
                      activeColor: AppColors.primary,
                      onChanged: (val) => setState(() => _speed = val),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Cao độ: ${_pitch.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
                        TextButton(
                          onPressed: () => setState(() => _pitch = 1.0),
                          child: const Text('Mặc định', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                    Slider(
                      value: _pitch,
                      min: 0.8,
                      max: 1.2,
                      divisions: 8,
                      activeColor: AppColors.accentCyan,
                      onChanged: (val) => setState(() => _pitch = val),
                    ),
                    const SizedBox(height: 10),
                    // Test Preview Button
                    OutlinedButton.icon(
                      onPressed: _previewSelectedVoice,
                      icon: Icon(_isPlayingTest ? Icons.stop_rounded : Icons.volume_up_rounded, size: 18),
                      label: Text(_isPlayingTest ? 'Dừng phát âm' : 'Nghe thử giọng mẫu'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryLight,
                        side: const BorderSide(color: AppColors.primaryLight),
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // SECTION 3: PERSONALITY & INTERACTION STYLE (For Mode 2 or presentation)
              if (!widget.isCustomizingBase) ...[
                Text('TÍNH CÁCH & PHONG CÁCH GIAO TIẾP',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary)),
                const SizedBox(height: 12),

                // Trait Chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _personalityTraits.map((trait) {
                    final isSel = _speakingStyle == trait;
                    return ChoiceChip(
                      label: Text(trait),
                      selected: isSel,
                      selectedColor: AppColors.primary.withOpacity(0.2),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: isSel ? AppColors.primaryLight : textSecondary,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (_) => setState(() => _speakingStyle = trait),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Pronoun Style
                TextFormField(
                  controller: _pronounController,
                  decoration: const InputDecoration(
                    labelText: 'Cách xưng hô mong muốn',
                    hintText: 'Ví dụ: Bạn - Mình, Em - Anh/Chị, Tôi - Bạn',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),

                // Custom Prompt Addition
                TextFormField(
                  controller: _customPersonalityController,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả tính cách tự do (nếu có)',
                    hintText: 'Ví dụ: Thích dùng từ ngữ hóm hỉnh, luôn khích lệ bạn bè...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
              ],

              // SUBMIT BUTTON
              ElevatedButton.icon(
                onPressed: _saveCharacter,
                icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                label: Text(
                  widget.isCustomizingBase
                      ? 'Lưu bản tùy chỉnh này'
                      : (widget.isEditingExisting ? 'Cập nhật nhân vật' : 'Tạo nhân vật & Bắt đầu'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  void _showAvatarPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Chọn biểu tượng đại diện', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: _emojiChoices.map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      setState(() => _avatar = emoji);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _avatar == emoji ? AppColors.primary.withOpacity(0.2) : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _avatar == emoji ? AppColors.primary : Colors.grey.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 26))),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}
