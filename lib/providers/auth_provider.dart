import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../models/models.dart';

class AuthProvider extends ChangeNotifier {
  final _api = ApiClient.instance;

  AppUser? user;
  bool cargando = true; // revisando sesión guardada al abrir la app

  bool get autenticado => user != null;

  AuthProvider() {
    _api.onUnauthorized = _sesionExpirada;
  }

  void _sesionExpirada() {
    if (user != null) {
      user = null;
      _api.clearToken();
      notifyListeners();
    }
  }

  /// Llamar al iniciar: si hay token guardado, recupera el usuario.
  Future<void> restaurarSesion() async {
    try {
      final token = await _api.getToken();
      if (token != null) {
        final r = await _api.get('/v1/user');
        user = AppUser.fromJson(r['user']);
      }
    } catch (_) {
      await _api.clearToken();
      user = null;
    }
    cargando = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final r = await _api.post('/v1/login', data: {'email': email, 'password': password});
    await _api.saveToken(r['token']);
    user = AppUser.fromJson(r['user']);
    notifyListeners();
  }

  /// Devuelve el mensaje del servidor (ej. "espera aprobación").
  Future<String> registrar(Map<String, dynamic> campos, {Map<String, String> archivos = const {}}) async {
    final r = await _api.postFormConArchivos('/v1/register', campos, archivos);
    await _api.saveToken(r['token']);
    user = AppUser.fromJson(r['user']);
    notifyListeners();
    return r['message'] ?? '';
  }

  Future<void> refrescarUsuario() async {
    final r = await _api.get('/v1/user');
    user = AppUser.fromJson(r['user']);
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await _api.post('/v1/logout');
    } catch (_) {}
    await _api.clearToken();
    user = null;
    notifyListeners();
  }
}
