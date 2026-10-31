import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../core/local_db.dart';
import '../core/sync_service.dart';
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
    LocalDb.usuarioId = 0;
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
        LocalDb.usuarioId = user!.id;
        await LocalDb.guardarGlobal('ultimo_usuario', r['user']);
      }
    } on ApiException catch (e) {
      if (e.sinConexion && await _api.getToken() != null) {
        // Sin internet: se conserva la sesión usando la copia local del usuario.
        final copia = await LocalDb.leerGlobal('ultimo_usuario');
        if (copia != null) {
          user = AppUser.fromJson(Map<String, dynamic>.from(copia as Map));
          LocalDb.usuarioId = user!.id;
        }
      } else {
        // Token inválido o vencido (401, etc.): sí se cierra la sesión.
        await _api.clearToken();
        user = null;
        LocalDb.usuarioId = 0;
      }
    } catch (_) {
      await _api.clearToken();
      user = null;
      LocalDb.usuarioId = 0;
    }
    cargando = false;
    await SyncService.refrescarContador();
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final r = await _api.post('/v1/login', data: {'email': email, 'password': password});
    await _api.saveToken(r['token']);
    user = AppUser.fromJson(r['user']);
    LocalDb.usuarioId = user!.id;
    await LocalDb.guardarGlobal('ultimo_usuario', r['user']);
    notifyListeners();
  }

  /// Devuelve el mensaje del servidor (ej. "espera aprobación").
  Future<String> registrar(Map<String, dynamic> campos, {Map<String, String> archivos = const {}}) async {
    final r = await _api.postFormConArchivos('/v1/register', campos, archivos);
    await _api.saveToken(r['token']);
    user = AppUser.fromJson(r['user']);
    LocalDb.usuarioId = user!.id;
    await LocalDb.guardarGlobal('ultimo_usuario', r['user']);
    notifyListeners();
    return r['message'] ?? '';
  }

  Future<void> refrescarUsuario() async {
    final r = await _api.get('/v1/user');
    user = AppUser.fromJson(r['user']);
    LocalDb.usuarioId = user!.id;
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await _api.post('/v1/logout');
    } catch (_) {}
    await _api.clearToken();
    user = null;
    LocalDb.usuarioId = 0;
    notifyListeners();
  }
}
