import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../features/character/data/models/ai_character_model.dart';

class CharacterStorageService {
  final SharedPreferences _prefs;
  static const String _keyCustomCharacters = 'polyvoice_custom_characters_v2';

  CharacterStorageService(this._prefs);

  /// Loads all user-created or user-customized characters.
  List<AICharacterModel> loadCustomCharacters() {
    final raw = _prefs.getString(_keyCustomCharacters);
    if (raw == null || raw.trim().isEmpty) {
      return [];
    }

    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list.map((item) => AICharacterModel.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Saves a new custom character or updates an existing one.
  Future<void> saveCustomCharacter(AICharacterModel character) async {
    final list = loadCustomCharacters();
    final index = list.indexWhere((c) => c.id == character.id);
    if (index >= 0) {
      list[index] = character;
    } else {
      list.insert(0, character);
    }

    final raw = jsonEncode(list.map((c) => c.toJson()).toList());
    await _prefs.setString(_keyCustomCharacters, raw);
  }

  /// Deletes a custom character by ID without affecting built-in base characters.
  Future<void> deleteCustomCharacter(String id) async {
    final list = loadCustomCharacters();
    list.removeWhere((c) => c.id == id);

    final raw = jsonEncode(list.map((c) => c.toJson()).toList());
    await _prefs.setString(_keyCustomCharacters, raw);
  }

  /// Finds a custom character by ID if present.
  AICharacterModel? findCustomCharacter(String id) {
    final list = loadCustomCharacters();
    try {
      return list.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}
