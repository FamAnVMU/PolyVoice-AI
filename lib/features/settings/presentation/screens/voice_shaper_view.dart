import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../voice/data/models/voice_model.dart';
import '../../../voice/data/preset_voices.dart';
import '../../../voice/presentation/widgets/create_custom_voice_dialog.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';

class VoiceShaperView extends StatefulWidget {
  const VoiceShaperView({super.key});

  @override
  State<VoiceShaperView> createState() => _VoiceShaperViewState();
}

class _VoiceShaperViewState extends State<VoiceShaperView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  String _selectedCategoryFilter = 'all';
  String _selectedAccentFilter = 'all';
  String? _currentlyPlayingVoiceId;

  // Standard Vietnamese evaluation corpus for testing TTS quality
  static const List<Map<String, String>> vietnameseBenchmarkCorpus = [
    {
      'title': '1. Trò chuyện tự nhiên',
      'category': 'Giao tiếp hằng ngày',
      'text': 'Xin chào! Rất vui được gặp bạn hôm nay. Bạn có khỏe không, công việc và cuộc sống dạo này thế nào rồi?',
    },
    {
      'title': '2. Giải thích kiến thức & Số liệu',
      'category': 'Xử lý số & Từ viết tắt',
      'text': 'Hôm nay là ngày 30/10/2026. Trí tuệ nhân tạo (AI) và công nghệ thông tin (CNTT) đang tăng trưởng hơn 150% mỗi năm tại TP.HCM và HN.',
    },
    {
      'title': '3. Kể chuyện & Ngữ điệu biểu cảm',
      'category': 'Sắc thái cảm xúc',
      'text': 'Ngày xửa ngày xưa, ở một ngôi làng nhỏ dưới chân núi mờ sương, có một dòng suối trong vắt róc rách chảy suốt bốn mùa... Thật là kỳ diệu!',
    },
    {
      'title': '4. Hướng dẫn & Ngắt nghỉ từng bước',
      'category': 'Nhịp điệu rành mạch',
      'text': 'Bước 1: Bạn hãy mở ứng dụng và chọn file âm thanh. Bước 2: Chờ hệ thống phân tích trong 5 giây. Cuối cùng, hãy nhấn nút lưu để hoàn tất.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _previewVoice(VoiceModel voice, String text, SettingsState state) async {
    final tts = context.read<SettingsBloc>().ttsService;

    if (_currentlyPlayingVoiceId == voice.id && tts.isPlaying) {
      await tts.stop();
      setState(() => _currentlyPlayingVoiceId = null);
      return;
    }

    setState(() => _currentlyPlayingVoiceId = voice.id);

    await tts.stop();
    await tts.speak(
      text,
      config: state.voiceConfig.copyWith(selectedVoiceId: voice.id),
      voice: voice,
      customVoices: state.customVoices,
    );

    if (mounted) {
      setState(() => _currentlyPlayingVoiceId = null);
    }
  }

  void _openCreateVoiceDialog(SettingsState state) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => CreateCustomVoiceDialog(
        elevenLabsApiKey: state.voiceConfig.elevenLabsApiKey,
        onVoiceCreated: (newVoice) {
          context.read<SettingsBloc>().add(SaveCustomVoiceEvent(newVoice));
          context.read<SettingsBloc>().add(SelectVoiceModelEvent(newVoice.id));
        },
      ),
    );
  }

  void _confirmDeleteVoice(VoiceModel voice) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        title: const Text('Xóa giọng nói cá nhân', style: TextStyle(color: Colors.white)),
        content: Text(
          'Bạn có chắc chắn muốn xóa giọng nói "${voice.name}" không? Thao tác này không thể hoàn tác.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<SettingsBloc>().add(DeleteCustomVoiceEvent(voice.id));
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        return Column(
          children: [
            // Sub-Tab Navigation Bar
            Container(
              color: Theme.of(context).cardColor,
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.accentPink,
                labelColor: AppColors.accentPink,
                unselectedLabelColor: Colors.grey,
                tabs: const [
                  Tab(icon: Icon(Icons.library_music_rounded, size: 20), text: 'Thư viện giọng'),
                  Tab(icon: Icon(Icons.record_voice_over, size: 20), text: 'Giọng cá nhân'),
                  Tab(icon: Icon(Icons.tune_rounded, size: 20), text: 'Điều chỉnh âm sắc'),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPresetsTab(state),
                  _buildCustomVoicesTab(state),
                  _buildFineTuningTab(state),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // -------------------------------------------------------------
  // TAB 1: THƯ VIỆN GIỌNG NÓI CÓ SẴN (PRESETS)
  // -------------------------------------------------------------
  Widget _buildPresetsTab(SettingsState state) {
    final query = _searchController.text.trim().toLowerCase();

    final filteredPresets = PresetVoices.allPresets.where((v) {
      if (query.isNotEmpty) {
        final matchName = v.name.toLowerCase().contains(query);
        final matchDesc = v.description.toLowerCase().contains(query);
        if (!matchName && !matchDesc) return false;
      }

      if (_selectedCategoryFilter != 'all') {
        if (_selectedCategoryFilter == 'female' && v.gender != 'female') return false;
        if (_selectedCategoryFilter == 'male' && v.gender != 'male') return false;
        if (_selectedCategoryFilter == 'gentle' && v.category != 'gentle') return false;
        if (_selectedCategoryFilter == 'warm' && v.category != 'warm') return false;
        if (_selectedCategoryFilter == 'dynamic' && v.category != 'dynamic') return false;
        if (_selectedCategoryFilter == 'storytelling' && v.category != 'storytelling') return false;
      }

      if (_selectedAccentFilter != 'all' && v.accent != _selectedAccentFilter) {
        return false;
      }

      return true;
    }).toList();

    return Column(
      children: [
        // Search & Filter Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Tìm kiếm giọng nói theo tên, phong cách...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() => _searchController.clear()),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ),

        // Category Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              _buildCategoryChip('all', 'Tất cả'),
              _buildCategoryChip('female', 'Nữ'),
              _buildCategoryChip('male', 'Nam'),
              _buildCategoryChip('gentle', 'Dịu dàng'),
              _buildCategoryChip('warm', 'Trầm ấm'),
              _buildCategoryChip('dynamic', 'Năng động'),
              _buildCategoryChip('storytelling', 'Kể chuyện'),
            ],
          ),
        ),

        // Accent Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Row(
            children: [
              _buildAccentChip('all', 'Tất cả vùng miền'),
              _buildAccentChip('north', 'Bắc (Hà Nội)'),
              _buildAccentChip('south', 'Nam (Sài Gòn)'),
              _buildAccentChip('central', 'Miền Trung'),
              _buildAccentChip('intl', 'Quốc tế / Song ngữ'),
            ],
          ),
        ),

        const Divider(height: 16),

        // Voice List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: filteredPresets.length,
            itemBuilder: (context, index) {
              final voice = filteredPresets[index];
              final isSelected = state.voiceConfig.selectedVoiceId == voice.id;
              final isPlaying = _currentlyPlayingVoiceId == voice.id;

              return Card(
                elevation: isSelected ? 4 : 1,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isSelected ? AppColors.accentPink : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: voice.gender == 'female'
                                ? AppColors.accentPink.withValues(alpha: 0.2)
                                : AppColors.primary.withValues(alpha: 0.2),
                            child: Icon(
                              voice.gender == 'female' ? Icons.face_3 : Icons.face,
                              color: voice.gender == 'female' ? AppColors.accentPink : AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      voice.name,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 6),
                                    if (isSelected)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.accentPink.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Text(
                                          'ĐANG DÙNG',
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.accentPink),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    _buildBadge(voice.genderLabel, Colors.blueGrey),
                                    const SizedBox(width: 4),
                                    _buildBadge(voice.accentLabel, Colors.teal),
                                    const SizedBox(width: 4),
                                    _buildBadge(voice.categoryLabel, Colors.purple),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Radio Selector Button
                          IconButton(
                            icon: Icon(
                              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                              color: isSelected ? AppColors.accentPink : Colors.grey,
                            ),
                            tooltip: 'Chọn làm giọng nói chính',
                            onPressed: () {
                              context.read<SettingsBloc>().add(SelectVoiceModelEvent(voice.id));
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        voice.description,
                        style: const TextStyle(fontSize: 12.5, color: Colors.grey, height: 1.35),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tốc độ mặc định: ${voice.defaultSpeed}x • Cao độ: ${voice.defaultPitch}x',
                            style: const TextStyle(fontSize: 11, color: Colors.white38),
                          ),
                          ElevatedButton.icon(
                            icon: Icon(isPlaying ? Icons.stop : Icons.volume_up, size: 16),
                            label: Text(isPlaying ? 'Dừng' : 'Nghe thử mẫu'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isPlaying ? AppColors.error : AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            onPressed: () => _previewVoice(voice, voice.sampleText, state),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(String id, String label) {
    final isSelected = _selectedCategoryFilter == id;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: isSelected,
        label: Text(label, style: TextStyle(fontSize: 11.5, color: isSelected ? Colors.white : null)),
        selectedColor: AppColors.accentPink,
        onSelected: (_) => setState(() => _selectedCategoryFilter = id),
      ),
    );
  }

  Widget _buildAccentChip(String id, String label) {
    final isSelected = _selectedAccentFilter == id;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: isSelected,
        label: Text(label, style: TextStyle(fontSize: 11.5, color: isSelected ? Colors.white : null)),
        selectedColor: AppColors.primary,
        onSelected: (_) => setState(() => _selectedAccentFilter = id),
      ),
    );
  }

  Widget _buildBadge(String text, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, color: color.shade200)),
    );
  }

  // -------------------------------------------------------------
  // TAB 2: GIỌNG NÓI CÁ NHÂN (CUSTOM CLONED VOICES)
  // -------------------------------------------------------------
  Widget _buildCustomVoicesTab(SettingsState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner introducing Custom Voice Creation
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.2),
                  AppColors.accentPink.withValues(alpha: 0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.auto_awesome, color: AppColors.accentPink, size: 28),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Voice Cloning Studio',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tự tạo giọng nói AI cá nhân từ file âm thanh (MP3, WAV, M4A) hoặc video (MP4, MOV). Hệ thống sẽ tự động tách audio, lọc chất lượng và nhân bản giọng đọc.',
                  style: TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.4),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openCreateVoiceDialog(state),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Tạo Giọng Nói Cá Nhân Mới'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentPink,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Text(
            'DANH SÁCH GIỌNG CÁ NHÂN CỦA BẠN',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.grey),
          ),
          const SizedBox(height: 12),

          if (state.customVoices.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Column(
                children: const [
                  Icon(Icons.mic_none_outlined, size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'Chưa có giọng nói cá nhân nào.',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Nhấn vào nút bên trên để import file hoặc ghi âm tạo giọng đầu tiên.',
                    style: TextStyle(fontSize: 12, color: Colors.white38),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ] else ...[
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.customVoices.length,
              itemBuilder: (context, index) {
                final voice = state.customVoices[index];
                final isSelected = state.voiceConfig.selectedVoiceId == voice.id;
                final isPlaying = _currentlyPlayingVoiceId == voice.id;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isSelected ? AppColors.accentPink : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.accentCyan.withValues(alpha: 0.2),
                              child: const Icon(Icons.person, color: AppColors.accentCyan),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(voice.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 6),
                                      if (isSelected)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: AppColors.accentPink.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text('ĐANG DÙNG', style: TextStyle(fontSize: 9, color: AppColors.accentPink, fontWeight: FontWeight.bold)),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${voice.genderLabel} • ${voice.accentLabel} • ${voice.engineType.toUpperCase()}',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                              tooltip: 'Xóa giọng nói này',
                              onPressed: () => _confirmDeleteVoice(voice),
                            ),
                            IconButton(
                              icon: Icon(
                                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                color: isSelected ? AppColors.accentPink : Colors.grey,
                              ),
                              tooltip: 'Chọn làm giọng chính',
                              onPressed: () {
                                context.read<SettingsBloc>().add(SelectVoiceModelEvent(voice.id));
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          voice.description,
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton.icon(
                              icon: Icon(isPlaying ? Icons.stop : Icons.volume_up, size: 16),
                              label: Text(isPlaying ? 'Dừng' : 'Nghe thử'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isPlaying ? AppColors.error : AppColors.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              ),
                              onPressed: () => _previewVoice(voice, voice.sampleText, state),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 3: BỘ ĐIỀU CHỈNH ÂM SẮC & PHÒNG THỬ NGHIỆM TIẾNG VIỆT
  // -------------------------------------------------------------
  Widget _buildFineTuningTab(SettingsState state) {
    final config = state.voiceConfig;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pacing & Rate Slider (Natural Conversational Speed)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tốc độ đọc (Speaking Rate)', style: TextStyle(fontWeight: FontWeight.w600)),
              Text(
                '${config.rate.toStringAsFixed(2)}x ${config.rate <= 0.88 ? "(Tự nhiên/Dễ nghe)" : config.rate > 1.1 ? "(Rất nhanh)" : "(Tiêu chuẩn)"}',
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
          const SizedBox(height: 12),

          // Vocal Pitch Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Cao độ giọng nói (Vocal Pitch)', style: TextStyle(fontWeight: FontWeight.w600)),
              Text(
                '${config.pitch.toStringAsFixed(2)}x ${config.pitch >= 1.25 ? "(Trẻ trung/Cute)" : config.pitch < 0.95 ? "(Trầm ấm)" : "(Tự nhiên)"}',
                style: const TextStyle(color: AppColors.accentPink, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Slider(
            value: config.pitch,
            min: 0.5,
            max: 1.8,
            divisions: 26,
            onChanged: (val) {
              final updated = config.copyWith(pitch: val);
              context.read<SettingsBloc>().add(UpdateVoiceConfigEvent(updated));
            },
          ),
          const SizedBox(height: 12),

          // Volume Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Âm lượng (Volume)', style: TextStyle(fontWeight: FontWeight.w600)),
              Text('${(config.volume * 100).toInt()}%', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
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
          const SizedBox(height: 12),

          // Emotion Intensity Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Mức độ biểu cảm (Emotion)', style: TextStyle(fontWeight: FontWeight.w600)),
              Text('${(config.emotion * 100).toInt()}%', style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: config.emotion,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            onChanged: (val) {
              final updated = config.copyWith(emotion: val);
              context.read<SettingsBloc>().add(UpdateVoiceConfigEvent(updated));
            },
          ),
          const SizedBox(height: 12),

          // Stability Slider (ElevenLabs & Neural parameter)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Độ ổn định giọng đọc (Stability)', style: TextStyle(fontWeight: FontWeight.w600)),
              Text('${(config.stability * 100).toInt()}%', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: config.stability,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            onChanged: (val) {
              final updated = config.copyWith(stability: val);
              context.read<SettingsBloc>().add(UpdateVoiceConfigEvent(updated));
            },
          ),
          const SizedBox(height: 20),

          // VIETNAMESE BENCHMARK EVALUATION TEST BENCH
          const Text(
            'BỘ CÂU VĂN TIẾNG VIỆT CHUẨN ĐỂ KIỂM THỬ CHẤT LƯỢNG',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          const Text(
            'Nhấn nghe thử từng câu dưới đây để đánh giá tốc độ ngắt nghỉ, khả năng đọc số, chữ viết tắt và cảm xúc với thiết lập hiện tại.',
            style: TextStyle(fontSize: 11.5, color: Colors.white60),
          ),
          const SizedBox(height: 12),

          ...vietnameseBenchmarkCorpus.map((item) {
            final activeVoice = PresetVoices.findById(config.selectedVoiceId);

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              color: Colors.black26,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.white12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(item['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accentCyan)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(6)),
                          child: Text(item['category']!, style: const TextStyle(fontSize: 10, color: Colors.white70)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(item['text']!, style: const TextStyle(fontSize: 12.5, color: Colors.white, height: 1.4)),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow, size: 16),
                        label: const Text('Phát thử câu này'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        onPressed: () => _previewVoice(activeVoice, item['text']!, state),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
