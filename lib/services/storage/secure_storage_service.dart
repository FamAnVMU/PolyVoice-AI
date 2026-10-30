import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants/app_constants.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  // Gemini Key
  Future<void> saveGeminiKey(String key) async {
    await _storage.write(key: AppConstants.keyGeminiApiKey, value: key.trim());
  }

  Future<String?> getGeminiKey() async {
    return await _storage.read(key: AppConstants.keyGeminiApiKey);
  }

  Future<void> deleteGeminiKey() async {
    await _storage.delete(key: AppConstants.keyGeminiApiKey);
  }

  // Groq Key
  Future<void> saveGroqKey(String key) async {
    await _storage.write(key: AppConstants.keyGroqApiKey, value: key.trim());
  }

  Future<String?> getGroqKey() async {
    return await _storage.read(key: AppConstants.keyGroqApiKey);
  }

  Future<void> deleteGroqKey() async {
    await _storage.delete(key: AppConstants.keyGroqApiKey);
  }

  // OpenRouter Key & Base URL
  Future<void> saveOpenRouterKey(String key) async {
    await _storage.write(key: AppConstants.keyOpenRouterApiKey, value: key.trim());
  }

  Future<String?> getOpenRouterKey() async {
    return await _storage.read(key: AppConstants.keyOpenRouterApiKey);
  }

  Future<void> deleteOpenRouterKey() async {
    await _storage.delete(key: AppConstants.keyOpenRouterApiKey);
  }

  Future<void> saveOpenRouterBaseUrl(String url) async {
    await _storage.write(key: AppConstants.keyOpenRouterBaseUrl, value: url.trim());
  }

  Future<String?> getOpenRouterBaseUrl() async {
    return await _storage.read(key: AppConstants.keyOpenRouterBaseUrl);
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
    await _storage.deleteAll();
  }
}
