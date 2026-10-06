/// URL base de tu servidor Laravel (SIN barra final).
///
/// - Emulador Android + `php artisan serve`:   http://10.0.2.2:8000
/// - Celular físico en la misma WiFi:           http://TU_IP_LOCAL:8000
///   (ejecuta el servidor con: php artisan serve --host=0.0.0.0)
/// - Producción:                                https://tudominio.com
class AppConfig {
  static const String baseUrl = 'http://10.0.2.2:8000';
  static const String apiUrl = '$baseUrl/api';
  static const String apiV1 = '$apiUrl/v1';

  /// Centro inicial del mapa (Santa Cruz de la Sierra).
  static const double defaultLat = -17.7833;
  static const double defaultLng = -63.1821;

  /// Cada cuántos segundos el lavador envía su GPS al servidor.
  static const int gpsIntervalSeconds = 15;
  /// Cada cuántos segundos el cliente refresca el estado/ubicación.
  static const int trackingIntervalSeconds = 10;
}
