import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../features/voice/data/models/voice_model.dart';

class VoiceStorageService {
  final SharedPreferences _prefs;

  VoiceStorageService(this._prefs);

  /// Loads all custom voices saved locally on the device.
  List<VoiceModel> loadCustomVoices() {
    final rawJson = _prefs.getString(AppConstants.keyCustomVoices);
    if (rawJson == null || rawJson.trim().isEmpty) {
      return [];
    }

    try {
      final List<dynamic> decoded = jsonDecode(rawJson) as List<dynamic>;
      return decoded.map((e) => VoiceModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Saves a new or updated custom voice.
  Future<void> saveCustomVoice(VoiceModel voice) async {
    final existing = loadCustomVoices();
    final index = existing.indexWhere((v) => v.id == voice.id);
    if (index >= 0) {
      existing[index] = voice;
    } else {
      existing.insert(0, voice);
    }

    final rawJson = jsonEncode(existing.map((e) => e.toJson()).toList());
    await _prefs.setString(AppConstants.keyCustomVoices, rawJson);
  }

  /// Deletes a custom voice by its ID.
  Future<void> deleteCustomVoice(String id) async {
    final existing = loadCustomVoices();
    existing.removeWhere((v) => v.id == id);

    final rawJson = jsonEncode(existing.map((e) => e.toJson()).toList());
    await _prefs.setString(AppConstants.keyCustomVoices, rawJson);
  }
}
