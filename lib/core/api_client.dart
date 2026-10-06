import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'config.dart';

/// Error legible para mostrar en pantalla.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 90), // el chat IA puede tardar
      headers: {'Accept': 'application/json'},
    ));
    _dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) async {
      final t = await _storage.read(key: _tokenKey);
      if (t != null) o.headers['Authorization'] = 'Bearer $t';
      h.next(o);
    }, onError: (e, h) {
      if (e.response?.statusCode == 401 && onUnauthorized != null) {
        onUnauthorized!();
      }
      h.next(e);
    }));
  }

  static final ApiClient instance = ApiClient._();
  static const _tokenKey = 'auth_token';
  final _storage = const FlutterSecureStorage();
  late final Dio _dio;

  /// Se ejecuta cuando el servidor responde 401 (token vencido).
  void Function()? onUnauthorized;

  Future<String?> getToken() => _storage.read(key: _tokenKey);
  Future<void> saveToken(String t) => _storage.write(key: _tokenKey, value: t);
  Future<void> clearToken() => _storage.delete(key: _tokenKey);

  ApiException _toException(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      String msg = (data['message'] ?? 'Error del servidor').toString();
      final errs = data['errors'];
      if (errs is Map && errs.isNotEmpty) {
        final first = errs.values.first;
        if (first is List && first.isNotEmpty) msg = first.first.toString();
      }
      return ApiException(msg, statusCode: e.response?.statusCode);
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return ApiException('No se pudo conectar con el servidor. Revisa tu conexión.');
    }
    return ApiException(
        'Error inesperado (${e.response?.statusCode ?? 'sin respuesta'}).',
        statusCode: e.response?.statusCode);
  }

  Future<Map<String, dynamic>> _run(Future<Response> Function() call) async {
    try {
      final r = await call();
      return Map<String, dynamic>.from(r.data as Map);
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) =>
      _run(() => _dio.get(path, queryParameters: query));

  Future<Map<String, dynamic>> post(String path, {Object? data}) =>
      _run(() => _dio.post(path, data: data));

  Future<Map<String, dynamic>> put(String path, {Object? data}) =>
      _run(() => _dio.put(path, data: data));

  Future<Map<String, dynamic>> delete(String path) => _run(() => _dio.delete(path));

  /// Envío multipart (archivos). `data` puede incluir MultipartFile.
  Future<Map<String, dynamic>> postForm(String path, Map<String, dynamic> data) =>
      _run(() => _dio.post(path, data: FormData.fromMap(data)));

  /// Multipart con archivos a partir de rutas locales: {campo: rutaArchivo}.
  Future<Map<String, dynamic>> postFormConArchivos(
      String path, Map<String, dynamic> data, Map<String, String> archivos) async {
    final form = Map<String, dynamic>.from(data);
    for (final e in archivos.entries) {
      form[e.key] = await MultipartFile.fromFile(e.value);
    }
    return postForm(path, form);
  }
}
