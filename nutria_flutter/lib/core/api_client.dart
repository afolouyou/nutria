import 'package:dio/dio.dart';

import 'storage.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  final String baseUrl;

  ApiClient({
    this.baseUrl = defaultBaseUrl,
    Duration connectTimeout = const Duration(seconds: 15),
    Duration receiveTimeout = const Duration(seconds: 120),
  }) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        headers: {'Content-Type': 'application/json'},
        responseType: ResponseType.json,
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  static const String defaultBaseUrl = 'https://nutria.shares.zrok.io/api';

  final SecureStorage _storage = SecureStorage();
  late final Dio _dio;

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> data) async {
    try {
      final response = await _dio.post<dynamic>(path, data: data);
      return _asMap(response.data);
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put<dynamic>(path, data: data);
      return _asMap(response.data);
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  Future<Map<String, dynamic>> get(String path) async {
    try {
      final response = await _dio.get<dynamic>(path);
      return _asMap(response.data);
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  Future<void> delete(String path) async {
    try {
      await _dio.delete<void>(path);
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final data = await post('/auth/login', {'email': email, 'password': password});
    final token = data['token'] ?? data['access_token'];
    if (token is! String || token.isEmpty) {
      throw const ApiException('Login failed: missing token');
    }
    await _storage.saveToken(token);
    return data;
  }

  Future<Map<String, dynamic>> register(String email, String password, String name) async {
    return post('/auth/register', {
      'email': email,
      'password': password,
      'name': name,
    });
  }

  Future<Map<String, dynamic>> socialLogin(String email, String name, String provider) async {
    return post('/auth/social', {
      'email': email,
      'name': name,
      'provider': provider,
    });
  }

  Future<Map<String, dynamic>> getMe() async {
    return get('/auth/me');
  }

  Future<List<dynamic>> getConversations() async {
    try {
      final response = await _dio.get<dynamic>('/conversations');
      final data = response.data;
      if (data is List) return data;
      return <dynamic>[];
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  Future<Map<String, dynamic>> getConversation(String id) async {
    return get('/conversations/$id');
  }

  Future<void> deleteConversation(String id) async {
    return delete('/conversations/$id');
  }

  Future<List<dynamic>> getPantryItems() async {
    try {
      final response = await _dio.get<dynamic>('/pantry/items');
      final data = response.data;
      if (data is List) return data;
      return <dynamic>[];
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  Future<Map<String, dynamic>> addPantryItem(
    String name,
    double quantity,
    String unit,
    String category,
  ) async {
    return post('/pantry/items', {
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'category': category,
    });
  }

  Future<Map<String, dynamic>> updatePantryItem(
    String id,
    String name,
    double quantity,
    String unit,
    String category,
  ) async {
    return put('/pantry/items/$id', {
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'category': category,
    });
  }

  Future<void> deletePantryItem(String id) async {
    return delete('/pantry/items/$id');
  }

  Future<Map<String, dynamic>> getRecipesRemaining() async {
    return get('/recipes/remaining');
  }

  Future<Map<String, dynamic>> getPlan() async {
    return get('/me/plan');
  }

  Future<Map<String, dynamic>> sendAvatar(String dataUrl) async {
    return post('/avatar', {'data': dataUrl});
  }

  Future<Map<String, dynamic>> deleteAvatar() async {
    try {
      final response = await _dio.delete<dynamic>('/avatar');
      return _asMap(response.data);
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  ApiException _toApiException(DioException e) {
    final statusCode = e.response?.statusCode;
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          'O servidor demorou para responder. Verifique sua conexão e tente novamente.',
          statusCode: statusCode,
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          'Não foi possível conectar ao servidor. Verifique sua internet e tente novamente.',
        );
      case DioExceptionType.badResponse:
        return ApiException(_extractMessage(e.response?.data, statusCode), statusCode: statusCode);
      case DioExceptionType.cancel:
        return const ApiException('Requisição cancelada');
      default:
        return ApiException('Erro inesperado. Tente novamente.', statusCode: statusCode);
    }
  }

  String _extractMessage(dynamic data, int? statusCode) {
    if (data is Map) {
      final detail = data['detail'] ?? data['message'] ?? data['error'];
      if (detail != null && detail.toString().trim().isNotEmpty) {
        return detail.toString();
      }
    }
    if (data is String && data.trim().isNotEmpty && !_looksLikeHtml(data)) {
      return data.trim();
    }
    if (statusCode != null && statusCode >= 500) {
      return 'Servidor indisponível no momento. Tente novamente em instantes.';
    }
    if (statusCode == 401) return 'Sessão expirada. Entre novamente.';
    if (statusCode != null) {
      return 'Não foi possível concluir a solicitação (código $statusCode).';
    }
    return 'Não foi possível concluir a solicitação. Tente novamente.';
  }

  bool _looksLikeHtml(String text) {
    final t = text.trim().toLowerCase();
    return t.startsWith('<!doctype') ||
        t.startsWith('<html') ||
        t.startsWith('<head') ||
        t.startsWith('<body') ||
        (t.startsWith('<') && RegExp(r'^<[a-z]').hasMatch(t));
  }
}
