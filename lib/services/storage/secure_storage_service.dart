import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants/app_constants.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants/app_constants.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage;
  final Map<String, String> _memoryCache = {};

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
                resetOnError: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  // Gemini Key
  Future<void> saveGeminiKey(String key) async {
    final clean = key.trim();
    _memoryCache[AppConstants.keyGeminiApiKey] = clean;
    try {
      await _storage.write(key: AppConstants.keyGeminiApiKey, value: clean);
    } catch (_) {}
  }

  Future<String?> getGeminiKey() async {
    try {
      final val = await _storage.read(key: AppConstants.keyGeminiApiKey);
      if (val != null && val.isNotEmpty) {
        _memoryCache[AppConstants.keyGeminiApiKey] = val;
        return val;
      }
    } catch (_) {}
    return _memoryCache[AppConstants.keyGeminiApiKey];
  }

  Future<void> deleteGeminiKey() async {
    _memoryCache.remove(AppConstants.keyGeminiApiKey);
    try {
      await _storage.delete(key: AppConstants.keyGeminiApiKey);
    } catch (_) {}
  }

  // Groq Key
  Future<void> saveGroqKey(String key) async {
    final clean = key.trim();
    _memoryCache[AppConstants.keyGroqApiKey] = clean;
    try {
      await _storage.write(key: AppConstants.keyGroqApiKey, value: clean);
    } catch (_) {}
  }

  Future<String?> getGroqKey() async {
    try {
      final val = await _storage.read(key: AppConstants.keyGroqApiKey);
      if (val != null && val.isNotEmpty) {
        _memoryCache[AppConstants.keyGroqApiKey] = val;
        return val;
      }
    } catch (_) {}
    return _memoryCache[AppConstants.keyGroqApiKey];
  }

  Future<void> deleteGroqKey() async {
    _memoryCache.remove(AppConstants.keyGroqApiKey);
    try {
      await _storage.delete(key: AppConstants.keyGroqApiKey);
    } catch (_) {}
  }

  // OpenRouter Key & Base URL
  Future<void> saveOpenRouterKey(String key) async {
    final clean = key.trim();
    _memoryCache[AppConstants.keyOpenRouterApiKey] = clean;
    try {
      await _storage.write(key: AppConstants.keyOpenRouterApiKey, value: clean);
    } catch (_) {}
  }

  Future<String?> getOpenRouterKey() async {
    try {
      final val = await _storage.read(key: AppConstants.keyOpenRouterApiKey);
      if (val != null && val.isNotEmpty) {
        _memoryCache[AppConstants.keyOpenRouterApiKey] = val;
        return val;
      }
    } catch (_) {}
    return _memoryCache[AppConstants.keyOpenRouterApiKey];
  }

  Future<void> deleteOpenRouterKey() async {
    _memoryCache.remove(AppConstants.keyOpenRouterApiKey);
    try {
      await _storage.delete(key: AppConstants.keyOpenRouterApiKey);
    } catch (_) {}
  }

  Future<void> saveOpenRouterBaseUrl(String url) async {
    final clean = url.trim();
    _memoryCache[AppConstants.keyOpenRouterBaseUrl] = clean;
    try {
      await _storage.write(key: AppConstants.keyOpenRouterBaseUrl, value: clean);
    } catch (_) {}
  }

  Future<String?> getOpenRouterBaseUrl() async {
    try {
      final val = await _storage.read(key: AppConstants.keyOpenRouterBaseUrl);
      if (val != null && val.isNotEmpty) {
        _memoryCache[AppConstants.keyOpenRouterBaseUrl] = val;
        return val;
      }
    } catch (_) {}
    return _memoryCache[AppConstants.keyOpenRouterBaseUrl];
  }

  // ElevenLabs Key (Voice Cloning Engine)
  Future<void> saveElevenLabsKey(String key) async {
    final clean = key.trim();
    _memoryCache[AppConstants.keyElevenLabsApiKey] = clean;
    try {
      await _storage.write(key: AppConstants.keyElevenLabsApiKey, value: clean);
    } catch (_) {}
  }

  Future<String?> getElevenLabsKey() async {
    try {
      final val = await _storage.read(key: AppConstants.keyElevenLabsApiKey);
      if (val != null && val.isNotEmpty) {
        _memoryCache[AppConstants.keyElevenLabsApiKey] = val;
        return val;
      }
    } catch (_) {}
    return _memoryCache[AppConstants.keyElevenLabsApiKey];
  }

  Future<void> deleteElevenLabsKey() async {
    _memoryCache.remove(AppConstants.keyElevenLabsApiKey);
    try {
      await _storage.delete(key: AppConstants.keyElevenLabsApiKey);
    } catch (_) {}
  }

  // Check if provider has active key
  Future<bool> hasKeyForProvider(String provider) async {
    switch (provider) {
      case AppConstants.providerGemini:
        final key = await getGeminiKey();
        return key != null && key.isNotEmpty;
      case AppConstants.providerGroq:
        final key = await getGroqKey();
        return key != null && key.isNotEmpty;
      case AppConstants.providerOpenRouter:
        final key = await getOpenRouterKey();
        return key != null && key.isNotEmpty;
      default:
        return false;
    }
  }

  // Clear all credentials
  Future<void> clearAllKeys() async {
    _memoryCache.clear();
    try {
      await _storage.deleteAll();
    } catch (_) {}
  }
}
