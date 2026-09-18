import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStorage {
  static const String _tokenKey = 'nutria_auth_token';
  static const String _themeKey = 'nutria_theme';
  static const String _defaultTheme = 'dark';
  static const String _fallbackPrefix = 'fallback_';

  static String? _cachedToken;
  static bool? _useFallback;

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> saveToken(String token) async {
    _cachedToken = token;
    await _write(_tokenKey, token);
  }

  Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    final token = await _read(_tokenKey);
    _cachedToken = token.isNotEmpty ? token : null;
    return _cachedToken;
  }

  Future<void> removeToken() async {
    _cachedToken = null;
    await _delete(_tokenKey);
  }

  Future<void> saveTheme(String theme) async {
    await _write(_themeKey, theme);
  }

  Future<String> getTheme() async {
    final value = await _read(_themeKey);
    return value.isNotEmpty ? value : _defaultTheme;
  }

  Future<String> _read(String key) async {
    if (_useFallback == true) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_fallbackPrefix + key) ?? '';
    }
    try {
      final value = await _storage.read(key: key);
      _useFallback = false;
      return value ?? '';
    } catch (_) {
      _useFallback = true;
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_fallbackPrefix + key) ?? '';
    }
  }

  Future<void> _write(String key, String value) async {
    if (_useFallback == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_fallbackPrefix + key, value);
      return;
    }
    try {
      await _storage.write(key: key, value: value);
      _useFallback = false;
    } catch (_) {
      _useFallback = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_fallbackPrefix + key, value);
    }
  }

  Future<void> _delete(String key) async {
    if (_useFallback == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_fallbackPrefix + key);
      return;
    }
    try {
      await _storage.delete(key: key);
      _useFallback = false;
    } catch (_) {
      _useFallback = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_fallbackPrefix + key);
    }
  }
}