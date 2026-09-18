import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/app_cache.dart';
import '../core/storage.dart';
import '../models/user.dart';

class AuthProvider extends ChangeNotifier {
  final _api = ApiClient();
  final _storage = SecureStorage();
  final _cache = AppCache.instance;

  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;
  String? get error => _error;

  Future<void> tryAutoLogin() async {
    final token = await _storage.getToken();
    if (token == null || token.isEmpty) return;

    final cachedUserId = await _cache.getActiveUserId();
    if (cachedUserId != null && cachedUserId.isNotEmpty) {
      _cache.bindUser(cachedUserId);
      final cachedUser = await _readCachedUser();
      if (cachedUser != null) {
        _user = cachedUser;
        notifyListeners();
      }
    }

    try {
      final data = await _api.getMe();
      final user = User.fromJson(data);
      _user = user;
      _applyUserBinding(user);
      notifyListeners();
    } catch (e) {
      if (_user == null) {
        await _storage.removeToken();
        _cache.clearUser();
        _cache.clearActiveUserId();
      }
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _api.post('/auth/login', {
        'email': email,
        'password': password,
      });
      final token = data['token'] ?? data['access_token'];
      if (token is! String || token.isEmpty) throw Exception('Token not found');
      await _storage.saveToken(token);
      final userData = data['user'];
      final user = userData != null
          ? User.fromJson(Map<String, dynamic>.from(userData as Map))
          : await _fetchUser();
      _user = user;
      _applyUserBinding(user);
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = _friendlyError(e.message);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Algo deu errado. Tente novamente.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String email, String password, String name) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _api.register(email, password, name);
      final token = data['token'] ?? data['access_token'];
      if (token is! String || token.isEmpty) throw Exception('Token not found');
      await _storage.saveToken(token);
      final userData = data['user'];
      final user = userData != null
          ? User.fromJson(Map<String, dynamic>.from(userData as Map))
          : await _fetchUser();
      _user = user;
      _applyUserBinding(user);
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = _friendlyError(e.message);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Algo deu errado. Tente novamente.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> socialLogin(String email, String name, String provider) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _api.socialLogin(email, name, provider);
      final token = data['token'] ?? data['access_token'];
      if (token is! String || token.isEmpty) throw Exception('Token not found');
      await _storage.saveToken(token);
      final userData = data['user'];
      final user = userData != null
          ? User.fromJson(Map<String, dynamic>.from(userData as Map))
          : await _fetchUser();
      _user = user;
      _applyUserBinding(user);
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = _friendlyError(e.message);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Algo deu errado. Tente novamente.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  String _friendlyError(String raw) {
    return switch (raw.trim().toLowerCase()) {
      'senha invalida' => 'Senha inválida',
      'conta nao encontrada para este email' => 'Conta não encontrada para este email',
      'ja existe uma conta com este email' => 'Já existe uma conta com este email',
      _ => raw,
    };
  }

  Future<void> logout() async {
    await _storage.removeToken();
    _cache.clearUser();
    await _cache.clearActiveUserId();
    _user = null;
    notifyListeners();
  }

  Future<void> updateAvatar(String dataUrl) async {
    try {
      final data = await _api.sendAvatar(dataUrl);
      final userData = data['user'];
      if (userData != null) {
        final user = User.fromJson(Map<String, dynamic>.from(userData as Map));
        _user = user;
        _cache.writeJson(_cache.keyUser(), user.toJson());
      } else {
        final user = await _fetchUser();
        _user = user;
        _cache.writeJson(_cache.keyUser(), user.toJson());
      }
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  Future<void> removeAvatar() async {
    try {
      final data = await _api.deleteAvatar();
      final userData = data['user'];
      if (userData != null) {
        final user = User.fromJson(Map<String, dynamic>.from(userData as Map));
        _user = user;
        _cache.writeJson(_cache.keyUser(), user.toJson());
      } else {
        final user = await _fetchUser();
        _user = user;
        _cache.writeJson(_cache.keyUser(), user.toJson());
      }
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  Future<User> _fetchUser() async {
    final data = await _api.getMe();
    return User.fromJson(data);
  }

  void _applyUserBinding(User user) {
    _cache.bindUser(user.id);
    _cache.setActiveUserId(user.id);
    _cache.writeJson(_cache.keyUser(), user.toJson());
  }

  Future<User?> _readCachedUser() async {
    final data = await _cache.readJson<Map<String, dynamic>>(_cache.keyUser());
    if (data == null) return null;
    try {
      return User.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
