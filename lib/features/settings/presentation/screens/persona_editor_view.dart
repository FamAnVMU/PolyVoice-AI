import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/persona_model.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';

class PersonaEditorView extends StatelessWidget {
  const PersonaEditorView({super.key});

  void _showAddCustomPersonaDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final emojiCtrl = TextEditingController(text: '✨');
    final promptCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Create Custom Persona'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: TextField(
                        controller: emojiCtrl,
                        decoration: const InputDecoration(labelText: 'Emoji'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Persona Name'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Short Description'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: promptCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'System Prompt Instructions',
                    hintText: 'Describe how your companion should speak, behave, and react...',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty || promptCtrl.text.trim().isEmpty) return;

                final newPersona = PersonaModel(
                  id: const Uuid().v4(),
                  name: nameCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                  avatarEmoji: emojiCtrl.text.trim().isNotEmpty ? emojiCtrl.text.trim() : '✨',
                  systemPrompt: promptCtrl.text.trim(),
                  isBuiltIn: false,
                );

                context.read<SettingsBloc>().add(SaveCustomPersonaEvent(newPersona));
                Navigator.pop(dialogCtx);
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  void _showEditPromptDialog(BuildContext context, PersonaModel persona) {
    final promptCtrl = TextEditingController(text: persona.systemPrompt);

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text('Edit: ${persona.name}'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Inject expression words or personality guidelines below:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: promptCtrl,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    hintText: 'System prompt instructions...',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final updated = persona.copyWith(systemPrompt: promptCtrl.text.trim());
                if (persona.isBuiltIn) {
                  // Save copy as custom
                  final customCopy = updated.copyWith(
                    id: const Uuid().v4(),
                    name: '${persona.name} (Custom)',
                    isBuiltIn: false,
                  );
                  context.read<SettingsBloc>().add(SaveCustomPersonaEvent(customCopy));
                } else {
                  context.read<SettingsBloc>().add(SaveCustomPersonaEvent(updated));
                }
                Navigator.pop(dialogCtx);
              },
              child: const Text('Save Prompt'),
            ),
          ],
        );
      },
    );
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'SYSTEM PERSONAS',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.grey),
                  ),
                  TextButton.icon(
                    onPressed: () => _showAddCustomPersonaDialog(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New Persona'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Persona Cards List
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.personas.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final persona = state.personas[index];
                  final isSelected = persona.id == state.activePersona.id;

                  return InkWell(
                    onTap: () {
                      context.read<SettingsBloc>().add(SelectPersonaEvent(persona));
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : Theme.of(context).cardTheme.color,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.darkCardBorder,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(persona.avatarEmoji, style: const TextStyle(fontSize: 28)),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          persona.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        if (isSelected) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Text(
                                              'Active',
                                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      persona.description,
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_note, size: 22),
                                tooltip: 'Edit System Prompt',
                                onPressed: () => _showEditPromptDialog(context, persona),
                              ),
                              if (!persona.isBuiltIn)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                                  tooltip: 'Delete',
                                  onPressed: () {
                                    context.read<SettingsBloc>().add(DeleteCustomPersonaEvent(persona.id));
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // System prompt snippet
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              persona.systemPrompt,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }
}
