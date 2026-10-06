import '../models/models.dart';
import 'api_client.dart';

/// Capa de acceso a datos: cada método corresponde a un endpoint de Laravel.
class Repo {
  static final _api = ApiClient.instance;

  static List<T> _list<T>(Map<String, dynamic> r, T Function(Map<String, dynamic>) f) =>
      (r['data'] as List).map((e) => f(Map<String, dynamic>.from(e))).toList();

  // ---- Comunes ----
  static Future<List<Servicio>> servicios() async =>
      _list(await _api.get('/v1/servicios'), Servicio.fromJson);

  static Future<List<Notificacion>> notificaciones() async =>
      _list(await _api.get('/v1/notificaciones'), Notificacion.fromJson);

  static Future<int> contadorNotificaciones() async {
    final r = await _api.get('/v1/notificaciones/contador');
    return r['data']['no_leidas'] ?? 0;
  }

  static Future<void> leerNotificacion(String id) => _api.post('/v1/notificaciones/$id/leer');
  static Future<void> leerTodasNotificaciones() => _api.post('/v1/notificaciones/leer-todas');

  // ---- Cliente ----
  static Future<List<Vehiculo>> vehiculos() async =>
      _list(await _api.get('/v1/cliente/vehiculos'), Vehiculo.fromJson);

  static Future<void> crearVehiculo(Map<String, dynamic> d) => _api.post('/v1/cliente/vehiculos', data: d);
  static Future<void> actualizarVehiculo(int id, Map<String, dynamic> d) => _api.put('/v1/cliente/vehiculos/$id', data: d);
  static Future<void> eliminarVehiculo(int id) => _api.delete('/v1/cliente/vehiculos/$id');

  static Future<List<Cita>> citasCliente() async =>
      _list(await _api.get('/v1/cliente/citas'), Cita.fromJson);

  static Future<Cita> citaCliente(int id) async =>
      Cita.fromJson((await _api.get('/v1/cliente/citas/$id'))['data']);

  static Future<Cita> crearCita(Map<String, dynamic> d) async =>
      Cita.fromJson((await _api.post('/v1/cliente/citas', data: d))['data']);

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

  static Future<List<Cita>> citasLavador({String? tipo}) async =>
      _list(await _api.get('/v1/lavador/citas', query: tipo == null ? null : {'tipo': tipo}), Cita.fromJson);

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
