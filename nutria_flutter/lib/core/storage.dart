import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const String _tokenKey = 'nutria_auth_token';
  static const String _themeKey = 'nutria_theme';
  static const String _defaultTheme = 'dark';

  static String? _cachedToken;

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> saveToken(String token) async {
    _cachedToken = token;
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    final token = await _storage.read(key: _tokenKey);
    _cachedToken = token;
    return token;
  }

  Future<void> removeToken() async {
    _cachedToken = null;
    await _storage.delete(key: _tokenKey);
  }

  Future<void> saveTheme(String theme) async {
    await _storage.write(key: _themeKey, value: theme);
  }

  Future<String> getTheme() async {
    return await _storage.read(key: _themeKey) ?? _defaultTheme;
  }
}
