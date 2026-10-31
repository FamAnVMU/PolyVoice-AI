import 'package:equatable/equatable.dart';
import '../../../character/data/character_library.dart';
import '../../../character/data/models/ai_character_model.dart';
import '../../../profile/data/models/user_profile_model.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/chat_session.dart';

class ChatState extends Equatable {
  final List<ChatMessage> messages;
  final bool isStreaming;
  final bool isListeningStt;
  final String sttTranscriptPreview;
  final bool isSpeakingTts;
  final String? activeSpeakingMessageId;
  final bool isAutoScrollLocked;
  final String? errorMessage;

  // Multi-session & Characters
  final List<ChatSession> allSessions;
  final ChatSession? activeSession;
  final List<AICharacterModel> customCharacters;
  final UserProfileModel userProfile;
  final String sessionFilter; // 'all' | 'pinned' | 'archived'
  final String searchQuery;

  const ChatState({
    this.messages = const [],
    this.isStreaming = false,
    this.isListeningStt = false,
    this.sttTranscriptPreview = '',
    this.isSpeakingTts = false,
    this.activeSpeakingMessageId,
    this.isAutoScrollLocked = false,
    this.errorMessage,
    this.allSessions = const [],
    this.activeSession,
    this.customCharacters = const [],
    this.userProfile = const UserProfileModel(),
    this.sessionFilter = 'all',
    this.searchQuery = '',
  });

  /// Returns combined list of built-in base characters and user custom characters
  List<AICharacterModel> get allCharacters =>
      CharacterLibrary.getAllCharacters(customCharacters: customCharacters);

  /// Filtered sessions based on active filter tab and search text
  List<ChatSession> get filteredSessions {
    var list = allSessions;
    if (sessionFilter == 'pinned') {
      list = list.where((s) => s.isPinned && !s.isArchived).toList();
    } else if (sessionFilter == 'archived') {
      list = list.where((s) => s.isArchived).toList();
    } else {
      // 'all' tab shows non-archived sessions (with pinned first)
      list = list.where((s) => !s.isArchived).toList();
    }

    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      list = list.where((s) {
        final title = s.title.toLowerCase();
        final charName = s.characterName.toLowerCase();
        final lastMsg = s.messages.isNotEmpty ? s.messages.last.content.toLowerCase() : '';
        return title.contains(q) || charName.contains(q) || lastMsg.contains(q);
      }).toList();
    }

    // Sort: pinned first, then updated recently
    final sorted = List<ChatSession>.from(list);
    sorted.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return sorted;
  }

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isStreaming,
    bool? isListeningStt,
    String? sttTranscriptPreview,
    bool? isSpeakingTts,
    String? activeSpeakingMessageId,
    bool? isAutoScrollLocked,
    String? errorMessage,
    List<ChatSession>? allSessions,
    ChatSession? activeSession,
    List<AICharacterModel>? customCharacters,
    UserProfileModel? userProfile,
    String? sessionFilter,
    String? searchQuery,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isStreaming: isStreaming ?? this.isStreaming,
      isListeningStt: isListeningStt ?? this.isListeningStt,
      sttTranscriptPreview: sttTranscriptPreview ?? this.sttTranscriptPreview,
      isSpeakingTts: isSpeakingTts ?? this.isSpeakingTts,
      activeSpeakingMessageId: activeSpeakingMessageId ?? this.activeSpeakingMessageId,
      isAutoScrollLocked: isAutoScrollLocked ?? this.isAutoScrollLocked,
      errorMessage: errorMessage,
      allSessions: allSessions ?? this.allSessions,
      activeSession: activeSession ?? this.activeSession,
      customCharacters: customCharacters ?? this.customCharacters,
      userProfile: userProfile ?? this.userProfile,
      sessionFilter: sessionFilter ?? this.sessionFilter,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [
        messages,
        isStreaming,
        isListeningStt,
        sttTranscriptPreview,
        isSpeakingTts,
        activeSpeakingMessageId,
        isAutoScrollLocked,
        errorMessage,
        allSessions,
        activeSession,
        customCharacters,
        userProfile,
        sessionFilter,
        searchQuery,
      ];
}
