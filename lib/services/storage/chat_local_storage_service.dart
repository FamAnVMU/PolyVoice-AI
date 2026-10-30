import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../features/chat/data/models/chat_session.dart';

class ChatLocalStorageService {
  final SharedPreferences _prefs;

  ChatLocalStorageService(this._prefs);

  static Future<ChatLocalStorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return ChatLocalStorageService(prefs);
  }

  // Load all sessions
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

  // Save all sessions
  Future<void> saveSessions(List<ChatSession> sessions) async {
    final list = sessions.map((s) => s.toJson()).toList();
    await _prefs.setString(AppConstants.keyChatHistory, jsonEncode(list));
  }

  // Save or update a single session
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

  // Delete session
  Future<void> deleteSession(String sessionId) async {
    final sessions = loadSessions();
    sessions.removeWhere((s) => s.id == sessionId);
    await saveSessions(sessions);
  }

  // Clear all chat history
  Future<void> clearAll() async {
    await _prefs.remove(AppConstants.keyChatHistory);
  }
}
