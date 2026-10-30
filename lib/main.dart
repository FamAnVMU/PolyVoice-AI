import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'features/chat/presentation/bloc/chat_bloc.dart';
import 'features/chat/presentation/bloc/chat_event.dart';
import 'features/chat/presentation/screens/chat_screen.dart';
import 'features/navigation/presentation/screens/main_navigation_screen.dart';
import 'features/settings/presentation/bloc/settings_bloc.dart';
import 'features/settings/presentation/bloc/settings_event.dart';
import 'features/settings/presentation/bloc/settings_state.dart';
import 'services/llm/llm_service_factory.dart';
import 'services/pipeline/voice_pipeline_coordinator.dart';
import 'services/storage/chat_local_storage_service.dart';
import 'services/storage/secure_storage_service.dart';
import 'services/voice/stt_service.dart';
import 'services/voice/tts_queue_manager.dart';
import 'services/voice/tts_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Local & Secure Storage
  final prefs = await SharedPreferences.getInstance();
  final secureStorage = SecureStorageService();
  final chatStorage = ChatLocalStorageService(prefs);

  // Initialize Voice & AI Services
  final ttsService = TtsService();
  final sttService = SttService();
  final ttsQueueManager = TtsQueueManager(ttsService);
  final llmFactory = LlmServiceFactory();

  // Initialize Orchestrator Pipeline Coordinator
  final coordinator = VoicePipelineCoordinator(
    sttService: sttService,
    ttsQueueManager: ttsQueueManager,
    llmFactory: llmFactory,
  );

  runApp(PolyVoiceApp(
    prefs: prefs,
    secureStorage: secureStorage,
    chatStorage: chatStorage,
    ttsService: ttsService,
    llmFactory: llmFactory,
    coordinator: coordinator,
  ));
}

class PolyVoiceApp extends StatelessWidget {
  final SharedPreferences prefs;
  final SecureStorageService secureStorage;
  final ChatLocalStorageService chatStorage;
  final TtsService ttsService;
  final LlmServiceFactory llmFactory;
  final VoicePipelineCoordinator coordinator;

  const PolyVoiceApp({
    super.key,
    required this.prefs,
    required this.secureStorage,
    required this.chatStorage,
    required this.ttsService,
    required this.llmFactory,
    required this.coordinator,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<SettingsBloc>(
          create: (_) => SettingsBloc(
            secureStorage: secureStorage,
            prefs: prefs,
            ttsService: ttsService,
            llmFactory: llmFactory,
          )..add(LoadSettingsEvent()),
        ),
        BlocProvider<ChatBloc>(
          create: (context) => ChatBloc(
            coordinator: coordinator,
            storageService: chatStorage,
            settingsBloc: context.read<SettingsBloc>(),
          )..add(LoadChatHistoryEvent()),
        ),
      ],
      child: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, settingsState) {
          return MaterialApp(
            title: 'PolyVoice AI',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: settingsState.themeMode,
            home: const MainNavigationScreen(),
          );
        },
      ),
    );
  }
}
