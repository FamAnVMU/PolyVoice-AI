import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/ai_model_info.dart';

class ModelSelectionSheet extends StatefulWidget {
  final String provider;
  final String currentModel;

  const ModelSelectionSheet({
    super.key,
    required this.provider,
    required this.currentModel,
  });

  static Future<String?> show(BuildContext context, {required String provider, required String currentModel}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ModelSelectionSheet(provider: provider, currentModel: currentModel),
    );
  }

  @override
  State<ModelSelectionSheet> createState() => _ModelSelectionSheetState();
}

class _ModelSelectionSheetState extends State<ModelSelectionSheet> {
  late String _selectedModel;
  final TextEditingController _customModelController = TextEditingController();
  bool _isEnteringCustom = false;

  @override
  void initState() {
    super.initState();
    _selectedModel = widget.currentModel;
  }

  @override
  void dispose() {
    _customModelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final models = AiModelCatalog.getModelsForProvider(widget.provider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lựa chọn mô hình AI',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Chọn mô hình tối ưu cho tác vụ của bạn',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isEnteringCustom = !_isEnteringCustom;
                    });
                  },
                  child: Text(
                    _isEnteringCustom ? 'Xem danh sách' : 'Tự nhập model',
                    style: const TextStyle(fontSize: 12, color: AppColors.primaryLight),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          if (_isEnteringCustom) ...[
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nhập mã định danh mô hình (Model Identifier):',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _customModelController,
                    decoration: InputDecoration(
                      hintText: 'e.g. gpt-4o, claude-3-7-sonnet-20250219, mistral-large...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      prefixIcon: const Icon(Icons.code_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () {
                        final custom = _customModelController.text.trim();
                        if (custom.isNotEmpty) {
                          Navigator.of(context).pop(custom);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Áp dụng Model này', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shrinkWrap: true,
                itemCount: models.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final model = models[index];
                  final isSelected = _selectedModel == model.id;

                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop(model.id);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withOpacity(0.12)
                            : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02)),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : borderColor,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Text(
                                      model.name,
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? AppColors.primaryLight : textPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: model.isRecommended
                                            ? AppColors.accentCyan.withOpacity(0.18)
                                            : Colors.grey.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        model.tag,
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: model.isRecommended ? AppColors.accentCyan : textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                                color: isSelected ? AppColors.primaryLight : Colors.grey,
                                size: 20,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            model.description,
                            style: TextStyle(fontSize: 11.5, color: textSecondary, height: 1.3),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.layers_rounded, size: 12, color: textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                'Ngữ cảnh: ${model.contextLength}',
                                style: TextStyle(fontSize: 10.5, color: textSecondary, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(width: 12),
                              Icon(Icons.terminal_rounded, size: 12, color: textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                model.id,
                                style: TextStyle(fontSize: 10.5, color: textSecondary, fontFamily: 'monospace'),
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
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
