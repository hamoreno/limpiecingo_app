import 'package:geolocator/geolocator.dart';

class LocationHelper {
  /// Pide permisos y devuelve la posición actual (lanza String legible si falla).
  static Future<Position> actual() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw 'Activa el GPS de tu teléfono.';
    }
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied) throw 'Permiso de ubicación denegado.';
    if (permiso == LocationPermission.deniedForever) {
      throw 'El permiso de ubicación está bloqueado. Habilítalo en Ajustes de Android.';
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }
}
