import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../features/chat/data/models/chat_session.dart';
import '../../features/profile/data/models/user_profile_model.dart';

class ChatLocalStorageService {
  final SharedPreferences _prefs;
  static const String keyUserProfile = 'polyvoice_user_profile';
  static const String keyDataVersion = 'polyvoice_data_schema_version';
  static const int currentSchemaVersion = 2;

  ChatLocalStorageService(this._prefs) {
    _runMigrationIfNeeded();
  }

  static Future<ChatLocalStorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return ChatLocalStorageService(prefs);
  }

  void _runMigrationIfNeeded() {
    final version = _prefs.getInt(keyDataVersion) ?? 1;
    if (version < currentSchemaVersion) {
      // Migrate existing sessions into version 2 format (per-character persona schema)
      final existingSessions = loadSessions();
      saveSessions(existingSessions);
      _prefs.setInt(keyDataVersion, currentSchemaVersion);
    }
  }

  // -------------------------------------------------------------
  // USER PROFILE & PERSONALIZATION
  // -------------------------------------------------------------
  UserProfileModel loadUserProfile() {
    final raw = _prefs.getString(keyUserProfile);
    if (raw == null || raw.isEmpty) {
      return const UserProfileModel();
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return UserProfileModel.fromJson(map);
    } catch (_) {
      return const UserProfileModel();
    }
  }

  Future<void> saveUserProfile(UserProfileModel profile) async {
    await _prefs.setString(keyUserProfile, jsonEncode(profile.toJson()));
  }

  // -------------------------------------------------------------
  // CHAT SESSIONS MANAGEMENT
  // -------------------------------------------------------------
  List<ChatSession> loadSessions() {
    final rawData = _prefs.getString(AppConstants.keyChatHistory);
    if (rawData == null || rawData.isEmpty) {
      return [];
    }
    try {
      final List<dynamic> list = jsonDecode(rawData) as List<dynamic>;
      return list
          .map((item) => ChatSession.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveSessions(List<ChatSession> sessions) async {
    final list = sessions.map((s) => s.toJson()).toList();
    await _prefs.setString(AppConstants.keyChatHistory, jsonEncode(list));
  }

  Future<void> saveSession(ChatSession session) async {
    final sessions = loadSessions();
    final index = sessions.indexWhere((s) => s.id == session.id);
    if (index >= 0) {
      sessions[index] = session;
    } else {
      sessions.insert(0, session);
    }
    await saveSessions(sessions);
  }

  Future<void> deleteSession(String sessionId) async {
    final sessions = loadSessions();
    sessions.removeWhere((s) => s.id == sessionId);
    await saveSessions(sessions);
  }

  Future<void> togglePinSession(String sessionId) async {
    final sessions = loadSessions();
    final idx = sessions.indexWhere((s) => s.id == sessionId);
    if (idx >= 0) {
      final current = sessions[idx];
      sessions[idx] = current.copyWith(isPinned: !current.isPinned);
      await saveSessions(sessions);
    }
  }

  Future<void> toggleArchiveSession(String sessionId) async {
    final sessions = loadSessions();
    final idx = sessions.indexWhere((s) => s.id == sessionId);
    if (idx >= 0) {
      final current = sessions[idx];
      sessions[idx] = current.copyWith(isArchived: !current.isArchived);
      await saveSessions(sessions);
    }
  }

  Future<void> clearAll() async {
    await _prefs.remove(AppConstants.keyChatHistory);
  }

  // -------------------------------------------------------------
  // BACKUP & RESTORE DATA
  // -------------------------------------------------------------
  String exportBackupData() {
    final sessions = loadSessions();
    final profile = loadUserProfile();
    final backupMap = {
      'app': 'PolyVoice AI',
      'version': currentSchemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'profile': profile.toJson(),
      'sessions': sessions.map((s) => s.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(backupMap);
  }

  Future<bool> importRestoreData(String jsonString) async {
    try {
      final map = jsonDecode(jsonString) as Map<String, dynamic>;
      if (map['profile'] is Map) {
        final profile = UserProfileModel.fromJson(map['profile'] as Map<String, dynamic>);
        await saveUserProfile(profile);
      }
      if (map['sessions'] is List) {
        final restoredSessions = (map['sessions'] as List<dynamic>)
            .map((item) => ChatSession.fromJson(item as Map<String, dynamic>))
            .toList();
        await saveSessions(restoredSessions);
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
