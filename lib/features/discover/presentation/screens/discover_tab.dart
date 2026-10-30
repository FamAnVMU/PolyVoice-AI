import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../character/data/character_library.dart';
import '../../../character/data/models/ai_character_model.dart';
import '../../../character/presentation/widgets/character_profile_dialog.dart';
import '../../../chat/presentation/bloc/chat_bloc.dart';
import '../../../chat/presentation/bloc/chat_event.dart';
import '../../../chat/presentation/screens/chat_screen.dart';

class DiscoverTab extends StatefulWidget {
  const DiscoverTab({super.key});

  @override
  State<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<DiscoverTab> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'all';
  String _selectedAgeSuitability = 'all';
  String _searchQuery = '';

  final List<Map<String, String>> _categories = const [
    {'key': 'all', 'label': 'Tất cả'},
    {'key': 'friends', 'label': 'Bạn bè & Đời sống'},
    {'key': 'education', 'label': 'Học tập & Ngoại ngữ'},
    {'key': 'experts', 'label': 'Chuyên gia & Tech'},
    {'key': 'entertainment', 'label': 'Giải trí & Nhập vai'},
    {'key': 'emotional_support', 'label': 'Tâm sự & Chữa lành'},
  ];

  final List<Map<String, String>> _ageFilters = const [
    {'key': 'all', 'label': 'Mọi lứa tuổi'},
    {'key': 'kids', 'label': 'Thiếu nhi'},
    {'key': 'teens', 'label': 'Học sinh & SV'},
    {'key': 'adults', 'label': 'Trưởng thành'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AICharacterModel> _filterCharacters() {
    final all = CharacterLibrary.getAllCharacters();
    return all.where((c) {
      if (_selectedCategory != 'all' && c.category != _selectedCategory) {
        return false;
      }
      if (_selectedAgeSuitability != 'all' &&
          c.ageSuitability != 'all' &&
          c.ageSuitability != _selectedAgeSuitability) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final matchName = c.name.toLowerCase().contains(q);
        final matchDesc = c.shortDescription.toLowerCase().contains(q);
        final matchTags = c.tags.any((t) => t.toLowerCase().contains(q));
        if (!matchName && !matchDesc && !matchTags) return false;
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

    final filtered = _filterCharacters();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Khám phá nhân vật AI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        elevation: 0,
        backgroundColor: Colors.transparent,
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
                hintText: 'Tìm kiếm nhân vật, tính cách, chuyên môn...',
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

          // Category Filter Chips (Horizontal)
          SizedBox(
            height: 38,
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
          const SizedBox(height: 8),

          // Age Suitability Filter Chips (Horizontal)
          SizedBox(
            height: 34,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _ageFilters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final age = _ageFilters[index];
                final isSelected = _selectedAgeSuitability == age['key'];
                return FilterChip(
                  label: Text(age['label']!),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedAgeSuitability = selected ? age['key']! : 'all';
                    });
                  },
                  labelStyle: TextStyle(
                    fontSize: 11,
                    color: isSelected ? AppColors.accentCyan : textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  backgroundColor: cardBg,
                  selectedColor: AppColors.accentCyan.withOpacity(0.18),
                  side: BorderSide(
                    color: isSelected ? AppColors.accentCyan : borderColor,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // Characters Grid
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.person_search_rounded, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(
                          'Không tìm thấy nhân vật phù hợp',
                          style: TextStyle(color: textSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.76,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final char = filtered[index];
                      return _buildCharacterCard(
                        context,
                        char,
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
  }

  Widget _buildCharacterCard(
    BuildContext context,
    AICharacterModel char,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: () => CharacterProfileDialog.show(context, char),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.accentCyan],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(char.avatar, style: const TextStyle(fontSize: 22)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
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
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              char.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              char.categoryLabel,
              style: TextStyle(
                fontSize: 10,
                color: AppColors.primaryLight,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                char.shortDescription,
                style: TextStyle(fontSize: 11, color: textSecondary, height: 1.25),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 32,
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
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Colors.white),
                label: const Text('Nhắn tin', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
