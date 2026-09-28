import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'secure_storage_service.g.dart';

class SecureStorageService {
  static const _apiKey = 'gemini_api_key';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveApiKey(String value) =>
      _storage.write(key: _apiKey, value: value);
  Future<String?> getApiKey() => _storage.read(key: _apiKey);
  Future<void> deleteApiKey() => _storage.delete(key: _apiKey);

  Future<void> saveValue(String key, String value) =>
      _storage.write(key: key, value: value);
  Future<String?> readValue(String key) => _storage.read(key: key);
  Future<void> deleteValue(String key) => _storage.delete(key: key);
}

@riverpod
SecureStorageService secureStorageService(Ref ref) => SecureStorageService();
