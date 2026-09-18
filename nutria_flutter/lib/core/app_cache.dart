import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AppCache {
  AppCache._();
  static final AppCache instance = AppCache._();

  static const String _userPrefix = 'user_';
  static const String _conversationsPrefix = 'conversations_';
  static const String _pantryPrefix = 'pantry_';
  static const String _recipesPrefix = 'recipes_';
  static const String _activeUserIdKey = 'active_user_id';

  String _userId = '';

  void bindUser(String userId) {
    _userId = userId;
  }

  void clearUser() {
    _userId = '';
  }

  String get _userIdPart => _userId.isEmpty ? 'anon' : _userId;

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _sp async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<T?> readJson<T>(String key) async {
    try {
      final raw = (await _sp).getString('$_userIdPart|$key');
      if (raw == null) return null;
      return jsonDecode(raw) as T;
    } catch (_) {
      return null;
    }
  }

  Future<List<T>?> readJsonList<T>(String key) async {
    try {
      final raw = (await _sp).getString('$_userIdPart|$key');
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.cast<T>();
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> writeJson(String key, Object value) async {
    await (await _sp).setString('$_userIdPart|$key', jsonEncode(value));
  }

  Future<void> remove(String key) async {
    await (await _sp).remove('$_userIdPart|$key');
  }

  Future<String?> getActiveUserId() async {
    return (await _sp).getString(_activeUserIdKey);
  }

  Future<void> setActiveUserId(String userId) async {
    await (await _sp).setString(_activeUserIdKey, userId);
  }

  Future<void> clearActiveUserId() async {
    await (await _sp).remove(_activeUserIdKey);
  }

  String keyUser() => '$_userPrefix$_userIdPart';
  String keyConversations() => '$_conversationsPrefix$_userIdPart';
  String keyPantry() => '$_pantryPrefix$_userIdPart';
  String keyRecipes() => '$_recipesPrefix$_userIdPart';
}