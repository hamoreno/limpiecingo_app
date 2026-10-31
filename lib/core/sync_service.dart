import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'local_db.dart';

/// Envía al servidor lo que se guardó sin conexión.
class SyncService {
  /// true cuando la última lectura salió del caché local por falta de internet.
  static final ValueNotifier<bool> offline = ValueNotifier(false);

  /// Cantidad de registros esperando para enviarse.
  static final ValueNotifier<int> pendientes = ValueNotifier(0);

  static bool _corriendo = false;

  /// tipo guardado en la cola -> endpoint de Laravel
  static const _rutas = {
    'crear_vehiculo': '/v1/cliente/vehiculos',
    'crear_cita': '/v1/cliente/citas',
  };

  static Future<void> refrescarContador() async {
    pendientes.value = await LocalDb.contarPendientes();
  }

  /// Recorre la cola en orden. Devuelve cuántos se enviaron y cuántos rechazó el servidor.
  static Future<({int enviados, int descartados})> sincronizar() async {
    if (_corriendo || LocalDb.usuarioId == 0) return (enviados: 0, descartados: 0);
    _corriendo = true;
    var enviados = 0, descartados = 0;
    try {
      for (final p in await LocalDb.pendientes()) {
        final id = p['id'] as int;
        final ruta = _rutas[p['tipo']];
        if (ruta == null) {
          await LocalDb.borrarPendiente(id);
          continue;
        }
        try {
          await ApiClient.instance.post(ruta, data: jsonDecode(p['payload'] as String));
          await LocalDb.borrarPendiente(id);
          enviados++;
          offline.value = false;
        } on ApiException catch (e) {
          if (e.sinConexion) {
            offline.value = true;
            break; // sigue sin internet: se reintenta más tarde
          }
          if (e.statusCode == 401) break; // sesión vencida
          // El servidor lo rechazó (duplicado o datos inválidos): se descarta para no bloquear la cola.
          await LocalDb.borrarPendiente(id);
          descartados++;
        }
      }
    } finally {
      _corriendo = false;
      await refrescarContador();
    }
    return (enviados: enviados, descartados: descartados);
  }
}
