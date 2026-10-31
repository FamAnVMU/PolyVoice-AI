import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../character/data/models/ai_character_model.dart';
import '../../../character/presentation/screens/character_editor_screen.dart';
import '../../../character/presentation/widgets/character_profile_dialog.dart';
import '../../../chat/presentation/bloc/chat_bloc.dart';
import '../../../chat/presentation/bloc/chat_event.dart';
import '../../../chat/presentation/bloc/chat_state.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';

class DiscoverTab extends StatefulWidget {
  const DiscoverTab({super.key});

  @override
  State<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<DiscoverTab> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'all';
  String _selectedGender = 'all';
  String _selectedOrigin = 'all'; // 'all', 'preset', 'custom'
  String _searchQuery = '';
  String? _currentlyPlayingCharId;

  final List<Map<String, String>> _categories = const [
    {'key': 'all', 'label': 'Tất cả'},
    {'key': 'friends', 'label': 'Bạn bè & Đời sống'},
    {'key': 'education', 'label': 'Học tập & Ngoại ngữ'},
    {'key': 'experts', 'label': 'Chuyên gia & Tech'},
    {'key': 'entertainment', 'label': 'Giải trí & Nhập vai'},
    {'key': 'emotional_support', 'label': 'Tâm sự & Chữa lành'},
  ];

  final List<Map<String, String>> _genderFilters = const [
    {'key': 'all', 'label': 'Mọi giới tính'},
    {'key': 'female', 'label': 'Nữ 👩'},
    {'key': 'male', 'label': 'Nam 👨'},
  ];

  final List<Map<String, String>> _originFilters = const [
    {'key': 'all', 'label': 'Tất cả nguồn'},
    {'key': 'preset', 'label': 'Nhân vật gốc'},
    {'key': 'custom', 'label': 'Tùy chỉnh của tôi'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _previewVoice(AICharacterModel char) {
    setState(() {
      _currentlyPlayingCharId = char.id;
    });

    final settings = context.read<SettingsBloc>().state;
    final coordinator = context.read<ChatBloc>().coordinator;
    coordinator.ttsQueueManager.stopAndClear();
    coordinator.ttsQueueManager.enqueue(
      char.sampleGreeting,
      settings.voiceConfig,
      voiceConfig: char.voiceConfig,
      geminiApiKey: settings.apiKeys.geminiKey,
    );

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _currentlyPlayingCharId == char.id) {
        setState(() {
          _currentlyPlayingCharId = null;
        });
      }
    });
  }

  List<AICharacterModel> _filterCharacters(List<AICharacterModel> allCharacters) {
    return allCharacters.where((c) {
      // Category filter
      if (_selectedCategory != 'all' && c.category != _selectedCategory) {
        return false;
      }
      // Gender filter
      if (_selectedGender != 'all' && c.gender != _selectedGender) {
        return false;
      }
      // Origin filter
      if (_selectedOrigin == 'preset' && c.isCustom) {
        return false;
      }
      if (_selectedOrigin == 'custom' && !c.isCustom) {
        return false;
      }
      // Search query
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final matchName = c.name.toLowerCase().contains(q);
        final matchDesc = c.shortDescription.toLowerCase().contains(q);
        final matchBio = c.detailedBio.toLowerCase().contains(q);
        final matchStyle = c.speakingStyle.toLowerCase().contains(q);
        final matchVoice = c.voiceConfig.voiceName.toLowerCase().contains(q);
        final matchTags = c.tags.any((t) => t.toLowerCase().contains(q));
        if (!matchName && !matchDesc && !matchBio && !matchStyle && !matchVoice && !matchTags) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder;

    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, chatState) {
        final allCharacters = chatState.allCharacters;
        final filtered = _filterCharacters(allCharacters);

        return Scaffold(
          backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
          appBar: AppBar(
            title: const Text(
              'Khám phá nhân vật AI',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            actions: [
              IconButton(
                tooltip: 'Tạo nhân vật mới',
                icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryLight),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CharacterEditorScreen(mode: CharacterEditorMode.createScratch),
                    ),
                  );
                },
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CharacterEditorScreen(mode: CharacterEditorMode.createScratch),
                ),
              );
            },
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 20),
            label: const Text(
              'Tạo nhân vật mới',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          body: Column(
            children: [
              // Search Field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm nhân vật, giọng nói, tính cách...',
                    hintStyle: TextStyle(fontSize: 13, color: textSecondary),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: cardBg,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
              ),

              // Origin Filter Tabs (Tất cả, Nhân vật gốc, Tùy chỉnh của tôi)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: Row(
                  children: _originFilters.map((origin) {
                    final isSelected = _selectedOrigin == origin['key'];
                    final count = origin['key'] == 'all'
                        ? allCharacters.length
                        : origin['key'] == 'preset'
                            ? allCharacters.where((c) => !c.isCustom).length
                            : allCharacters.where((c) => c.isCustom).length;

                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedOrigin = origin['key']!;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary.withOpacity(0.15) : cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : borderColor,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${origin['label']} ($count)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? AppColors.primaryLight : textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 6),

              // Category Filter Chips
              SizedBox(
                height: 36,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _selectedCategory == cat['key'];
                    return ChoiceChip(
                      label: Text(cat['label']!),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedCategory = cat['key']!;
                          });
                        }
                      },
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : textSecondary,
                      ),
                      selectedColor: AppColors.primary,
                      backgroundColor: cardBg,
                      side: BorderSide(color: isSelected ? AppColors.primary : borderColor),
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),

              // Gender Filter Chips
              SizedBox(
                height: 32,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _genderFilters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final g = _genderFilters[index];
                    final isSelected = _selectedGender == g['key'];
                    final color = g['key'] == 'female'
                        ? Colors.pink
                        : g['key'] == 'male'
                            ? Colors.blue
                            : AppColors.accentCyan;

                    return FilterChip(
                      label: Text(g['label']!),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedGender = selected ? g['key']! : 'all';
                        });
                      },
                      labelStyle: TextStyle(
                        fontSize: 11,
                        color: isSelected ? color : textSecondary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      backgroundColor: cardBg,
                      selectedColor: color.withOpacity(0.18),
                      side: BorderSide(color: isSelected ? color : borderColor),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),

              // Characters Grid
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _selectedOrigin == 'custom'
                                    ? Icons.person_add_alt_1_rounded
                                    : Icons.person_search_rounded,
                                size: 48,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _selectedOrigin == 'custom'
                                    ? 'Bạn chưa tạo nhân vật tùy chỉnh nào'
                                    : 'Không tìm thấy nhân vật phù hợp',
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _selectedOrigin == 'custom'
                                    ? 'Hãy tự tạo một nhân vật AI mang giọng nói, phong cách xưng hô và cá tính theo ý bạn!'
                                    : 'Thử đổi từ khóa hoặc bộ lọc để xem các nhân vật khác.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: textSecondary, fontSize: 13),
                              ),
                              if (_selectedOrigin == 'custom') ...[
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const CharacterEditorScreen(
                                          mode: CharacterEditorMode.createScratch,
                                        ),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                  ),
                                  icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                                  label: const Text(
                                    'Tạo nhân vật ngay',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.68,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final char = filtered[index];
                          final isPlaying = _currentlyPlayingCharId == char.id;
                          return _buildCharacterCard(
                            context,
                            char,
                            isPlaying,
                            cardBg,
                            borderColor,
                            textPrimary,
                            textSecondary,
                            isDark,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCharacterCard(
    BuildContext context,
    AICharacterModel char,
    bool isPlaying,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    final isMale = char.gender == 'male';

    return GestureDetector(
      onTap: () => CharacterProfileDialog.show(context, char),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isPlaying ? AppColors.accentCyan : borderColor,
            width: isPlaying ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isPlaying
                  ? AppColors.accentCyan.withOpacity(0.25)
                  : Colors.black.withOpacity(isDark ? 0.2 : 0.04),
              blurRadius: isPlaying ? 12 : 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Avatar + Gender & Custom badges + Voice Listen button
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isMale
                          ? [Colors.blue.shade600, AppColors.accentCyan]
                          : [Colors.pink.shade500, AppColors.primary],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(char.avatar, style: const TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: (isMale ? Colors.blue : Colors.pink).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isMale ? 'Nam ♂' : 'Nữ ♀',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isMale ? Colors.blue : Colors.pink,
                              ),
                            ),
                          ),
                          if (char.isCustom) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppColors.accentCyan.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Tùy chỉnh',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.accentCyan,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 12, color: AppColors.warning),
                          const SizedBox(width: 2),
                          Text(
                            char.rating.toString(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Audio preview icon button
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: Icon(
                    isPlaying ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                    size: 20,
                    color: isPlaying ? AppColors.accentCyan : AppColors.primaryLight,
                  ),
                  tooltip: 'Nghe thử giọng',
                  onPressed: () => _previewVoice(char),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Character Name
            Text(
              char.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // Category Label
            Text(
              char.categoryLabel,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.primaryLight,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),

            // Voice info badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.mic_none_rounded, size: 10, color: AppColors.accentCyan),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      '${char.voiceConfig.voiceName} • ${char.voiceConfig.speed}x',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // Short Description
            Expanded(
              child: Text(
                char.shortDescription,
                style: TextStyle(fontSize: 11, color: textSecondary, height: 1.25),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 6),

            // Action: Start Chat Button
            SizedBox(
              width: double.infinity,
              height: 30,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.read<ChatBloc>().add(CreateSessionWithCharacterEvent(char));
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ChatScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 13, color: Colors.white),
                label: const Text(
                  'Nhắn tin',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
