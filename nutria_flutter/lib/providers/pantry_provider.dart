import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/app_cache.dart';
import '../models/pantry_item.dart';

class PantryProvider extends ChangeNotifier {
  final _api = ApiClient();
  final _cache = AppCache.instance;

  List<PantryItem> _items = [];
  bool _isLoading = false;
  String? _error;

  List<PantryItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadItems() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    final cached = await _readCachedItems();
    if (cached != null && _items.isEmpty) {
      _items = cached;
      _isLoading = false;
      notifyListeners();
    }
    try {
      final data = await _api.getPantryItems();
      _items = data
          .whereType<Map<String, dynamic>>()
          .map(PantryItem.fromJson)
          .toList();
      _items.sort((a, b) => a.name.compareTo(b.name));
      await _cache.writeJson(
        _cache.keyPantry(),
        _items.map((i) => i.toJson()).toList(),
      );
    } catch (e) {
      if (_items.isEmpty) {
        _error = _msg(e);
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addItem(String name, double quantity, String unit, String category) async {
    try {
      await _api.addPantryItem(name, quantity, unit, category);
      await loadItems();
      return true;
    } catch (e) {
      _error = _msg(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateItem(String id, String name, double quantity, String unit, String category) async {
    try {
      await _api.updatePantryItem(id, name, quantity, unit, category);
      await loadItems();
      return true;
    } catch (e) {
      _error = _msg(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> deleteItem(String id) async {
    try {
      await _api.deletePantryItem(id);
      _items.removeWhere((item) => item.id == id);
      await _cache.writeJson(
        _cache.keyPantry(),
        _items.map((i) => i.toJson()).toList(),
      );
      notifyListeners();
    } catch (e) {
      _error = _msg(e);
      notifyListeners();
    }
  }

  Future<List<PantryItem>?> _readCachedItems() async {
    final raw = await _cache.readJsonList<Map<String, dynamic>>(_cache.keyPantry());
    if (raw == null) return null;
    try {
      return raw.map(PantryItem.fromJson).toList();
    } catch (_) {
      return null;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _msg(Object e) => e is ApiException ? e.message : e.toString();
}
