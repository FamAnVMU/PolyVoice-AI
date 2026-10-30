import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';
import 'api_keys_view.dart';
import 'persona_editor_view.dart';
import 'voice_shaper_view.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings & Customization'),
          actions: [
            BlocBuilder<SettingsBloc, SettingsState>(
              builder: (context, state) {
                final isDark = state.themeMode == ThemeMode.dark;
                return IconButton(
                  icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                  tooltip: 'Toggle Theme',
                  onPressed: () {
                    context.read<SettingsBloc>().add(ToggleThemeModeEvent());
                  },
                );
              },
            ),
          ],
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primaryLight,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(icon: Icon(Icons.key), text: 'BYOK Keys'),
              Tab(icon: Icon(Icons.face), text: 'Personas'),
              Tab(icon: Icon(Icons.graphic_eq), text: 'Voice Shaper'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ApiKeysView(),
            PersonaEditorView(),
            VoiceShaperView(),
          ],
        ),
      ),
    );
  }
}
