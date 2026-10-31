import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';
import 'api_keys_view.dart';
import 'app_system_settings_view.dart';
import 'voice_engine_settings_view.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cài đặt hệ thống', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          actions: [
            BlocBuilder<SettingsBloc, SettingsState>(
              builder: (context, state) {
                final isDark = state.themeMode == ThemeMode.dark;
                return IconButton(
                  icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                  tooltip: 'Chuyển giao diện Sáng / Tối',
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
              Tab(icon: Icon(Icons.record_voice_over_rounded), text: 'Động cơ Voice'),
              Tab(icon: Icon(Icons.tune_rounded), text: 'Hệ thống'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ApiKeysView(),
            VoiceEngineSettingsView(),
            AppSystemSettingsView(),
          ],
        ),
      ),
    );
  }
}
