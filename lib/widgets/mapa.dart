import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/config.dart';

const _tiles = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _userAgent = 'com.limpiecingo.app';

class MarcadorMapa {
  final LatLng punto;
  final IconData icono;
  final Color color;
  final String? etiqueta;
  const MarcadorMapa(this.punto, this.icono, this.color, {this.etiqueta});
}

/// Mapa de solo lectura con marcadores (cliente / lavador).
class MapaVista extends StatelessWidget {
  final List<MarcadorMapa> marcadores;
  final double alto;
  const MapaVista({super.key, required this.marcadores, this.alto = 220});

  @override
  Widget build(BuildContext context) {
    final centro = marcadores.isNotEmpty ? marcadores.first.punto : const LatLng(AppConfig.defaultLat, AppConfig.defaultLng);
    final controller = MapController();

    return SizedBox(
      height: alto,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: FlutterMap(
          mapController: controller,
          options: MapOptions(
            initialCenter: centro,
            initialZoom: 15,
            initialCameraFit: marcadores.length > 1
                ? CameraFit.coordinates(
                    coordinates: marcadores.map((m) => m.punto).toList(),
                    padding: const EdgeInsets.all(48),
                    maxZoom: 17,
                  )
                : null,
          ),
          children: [
            TileLayer(urlTemplate: _tiles, userAgentPackageName: _userAgent),
            MarkerLayer(
              markers: [
                for (final m in marcadores)
                  Marker(
                    point: m.punto,
                    width: 44,
                    height: 44,
                    child: Icon(m.icono, color: m.color, size: 40),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Pantalla para elegir un punto tocando el mapa. Devuelve LatLng.
class SelectorUbicacion extends StatefulWidget {
  final LatLng? inicial;
  const SelectorUbicacion({super.key, this.inicial});
  @override
  State<SelectorUbicacion> createState() => _SelectorUbicacionState();
}

class _SelectorUbicacionState extends State<SelectorUbicacion> {
  late LatLng _punto = widget.inicial ?? const LatLng(AppConfig.defaultLat, AppConfig.defaultLng);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Elige la ubicación')),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: _punto,
          initialZoom: 16,
          onTap: (_, p) => setState(() => _punto = p),
        ),
        children: [
          TileLayer(urlTemplate: _tiles, userAgentPackageName: _userAgent),
          MarkerLayer(markers: [
            Marker(point: _punto, width: 48, height: 48, child: const Icon(Icons.location_on, color: Colors.red, size: 46)),
          ]),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton(onPressed: () => Navigator.pop(context, _punto), child: const Text('Confirmar ubicación')),
        ),
      ),
    );
  }
}
