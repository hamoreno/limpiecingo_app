import '../models/models.dart';
import 'api_client.dart';
import 'local_db.dart';
import 'sync_service.dart';

/// Capa de acceso a datos: cada método corresponde a un endpoint de Laravel.
class Repo {
  static final _api = ApiClient.instance;

  static List<T> _list<T>(Map<String, dynamic> r, T Function(Map<String, dynamic>) f) =>
      (r['data'] as List).map((e) => f(Map<String, dynamic>.from(e))).toList();

  /// Lectura con respaldo local: si hay internet guarda copia en SQLite;
  /// si no hay conexión devuelve la última copia guardada.
  static Future<List<T>> _listaConCache<T>(
    String nombre,
    String path,
    T Function(Map<String, dynamic>) f, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final r = await _api.get(path, query: query);
      await LocalDb.guardar(nombre, r['data']);
      SyncService.offline.value = false;
      return _list(r, f);
    } on ApiException catch (e) {
      if (!e.sinConexion) rethrow;
      final copia = await LocalDb.leer(nombre);
      if (copia == null) rethrow; // nunca se descargó: no hay nada que mostrar
      SyncService.offline.value = true;
      return (copia as List).map((x) => f(Map<String, dynamic>.from(x))).toList();
    }
  }

  /// Escritura con cola: devuelve true si se envió, false si quedó guardada para después.
  static Future<bool> _enviarOEncolar(String tipo, String path, Map<String, dynamic> data) async {
    try {
      await _api.post(path, data: data);
      return true;
    } on ApiException catch (e) {
      if (!e.sinConexion) rethrow;
      await LocalDb.encolar(tipo, data);
      await SyncService.refrescarContador();
      return false;
    }
  }

  // ---- Comunes ----
  static Future<List<Servicio>> servicios() => _listaConCache('servicios', '/v1/servicios', Servicio.fromJson);

  static Future<List<Notificacion>> notificaciones() async =>
      _list(await _api.get('/v1/notificaciones'), Notificacion.fromJson);

  static Future<int> contadorNotificaciones() async {
    final r = await _api.get('/v1/notificaciones/contador');
    return r['data']['no_leidas'] ?? 0;
  }

  static Future<void> leerNotificacion(String id) => _api.post('/v1/notificaciones/$id/leer');
  static Future<void> leerTodasNotificaciones() => _api.post('/v1/notificaciones/leer-todas');

  // ---- Cliente ----
  static Future<List<Vehiculo>> vehiculos() => _listaConCache('vehiculos', '/v1/cliente/vehiculos', Vehiculo.fromJson);

  /// true = enviado al servidor; false = guardado sin conexión (se enviará solo).
  static Future<bool> crearVehiculo(Map<String, dynamic> d) => _enviarOEncolar('crear_vehiculo', '/v1/cliente/vehiculos', d);
  static Future<void> actualizarVehiculo(int id, Map<String, dynamic> d) => _api.put('/v1/cliente/vehiculos/$id', data: d);
  static Future<void> eliminarVehiculo(int id) => _api.delete('/v1/cliente/vehiculos/$id');

  static Future<List<Cita>> citasCliente() => _listaConCache('citas_cliente', '/v1/cliente/citas', Cita.fromJson);

  static Future<Cita> citaCliente(int id) async =>
      Cita.fromJson((await _api.get('/v1/cliente/citas/$id'))['data']);

  /// true = enviada al servidor; false = guardada sin conexión (se enviará sola).
  static Future<bool> crearCita(Map<String, dynamic> d) => _enviarOEncolar('crear_cita', '/v1/cliente/citas', d);

  static Future<void> cancelarCita(int id) => _api.post('/v1/cliente/citas/$id/cancelar');

  static Future<void> pagarCita(int id, String metodo, String rutaComprobante, String? obs) =>
      _api.postFormConArchivos('/v1/cliente/citas/$id/pagar', {
        'metodo_pago': metodo,
        if (obs != null && obs.isNotEmpty) 'observacion_pago': obs,
      }, {'comprobante_pago': rutaComprobante});

  static Future<void> enviarEncuesta(int id, int calificacion, String? comentario) =>
      _api.post('/v1/cliente/citas/$id/encuesta', data: {
        'calificacion': calificacion,
        if (comentario != null && comentario.isNotEmpty) 'comentario': comentario,
      });

  /// Devuelve null si el lavador aún no comparte ubicación.
  static Future<Map<String, dynamic>?> ubicacionLavador(int citaId) async {
    try {
      return Map<String, dynamic>.from((await _api.get('/v1/cliente/citas/$citaId/ubicacion-lavador'))['data']);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  // ---- Lavador ----
  static Future<Map<String, dynamic>> perfilLavador() async =>
      Map<String, dynamic>.from((await _api.get('/v1/lavador/perfil'))['data']);

  static Future<void> conectar() => _api.post('/v1/lavador/conectar');
  static Future<void> desconectar() => _api.post('/v1/lavador/desconectar');

  static Future<void> enviarUbicacion(double lat, double lng) =>
      _api.post('/v1/lavador/ubicacion', data: {'latitud': lat, 'longitud': lng});

  static Future<List<Cita>> solicitudes() async =>
      _list(await _api.get('/v1/lavador/solicitudes'), Cita.fromJson);

  static Future<void> aceptarSolicitud(int id) => _api.post('/v1/lavador/solicitudes/$id/aceptar');

  static Future<List<Cita>> citasLavador({String? tipo}) => _listaConCache(
        'citas_lavador_${tipo ?? 'todas'}',
        '/v1/lavador/citas',
        Cita.fromJson,
        query: tipo == null ? null : {'tipo': tipo},
      );

  static Future<Cita> citaLavador(int id) async =>
      Cita.fromJson((await _api.get('/v1/lavador/citas/$id'))['data']);

  static Future<void> enCamino(int id) => _api.post('/v1/lavador/citas/$id/en-camino');
  static Future<void> enProceso(int id) => _api.post('/v1/lavador/citas/$id/en-proceso');
  static Future<void> finalizarCita(int id, {String? observacion}) =>
      _api.post('/v1/lavador/citas/$id/finalizar',
          data: observacion == null || observacion.isEmpty ? {} : {'observacion_lavador': observacion});

  static Future<Ganancias> ganancias() async =>
      Ganancias.fromJson((await _api.get('/v1/lavador/ganancias'))['data']);

  // ---- Chat IA (Cingo) ----
  static Future<Map<String, dynamic>> chat(String mensaje, int? conversationId) async {
    final r = await _api.post('/ai/chat', data: {
      'message': mensaje,
      if (conversationId != null) 'conversation_id': conversationId,
    });
    return Map<String, dynamic>.from(r['data']);
  }
}
