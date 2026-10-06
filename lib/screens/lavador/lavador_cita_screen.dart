import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/repository.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import '../../widgets/fondo.dart';
import '../../widgets/mapa.dart';

class LavadorCitaScreen extends StatefulWidget {
  final int citaId;
  const LavadorCitaScreen({super.key, required this.citaId});
  @override
  State<LavadorCitaScreen> createState() => _LavadorCitaScreenState();
}

class _LavadorCitaScreenState extends State<LavadorCitaScreen> {
  Cita? _cita;
  String? _error;
  bool _trabajando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final c = await Repo.citaLavador(widget.citaId);
      if (mounted) setState(() { _cita = c; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _accion(Future<void> Function() f, String ok) async {
    setState(() => _trabajando = true);
    try {
      await f();
      if (mounted) snack(context, ok);
      await _cargar();
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  Future<void> _finalizar(Cita c) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Finalizar lavado'),
        content: TextField(controller: ctrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Observación (opcional)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Finalizar')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _trabajando = true);
    try {
      await Repo.finalizarCita(c.id, observacion: ctrl.text.trim());
      if (!mounted) return;
      snack(context, '¡Lavado finalizado! Ganancia registrada.');
      Navigator.pop(context, 'finalizada'); // la lista te lleva al Inicio
    } catch (e) {
      if (mounted) {
        snack(context, e.toString(), error: true);
        setState(() => _trabajando = false);
      }
    }
  }

  Future<void> _navegar(Cita c) async {
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${c.latitud},${c.longitud}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _fila(IconData i, String t, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(i, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$t: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(v)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final c = _cita;
    return FondoApp(child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: gradAppBar('Cita #${widget.citaId}'),
      body: c == null
          ? (_error != null ? VistaError(_error!, _cargar) : const Cargando())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                Row(children: [
                  Expanded(child: Text(c.servicioNombre, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                  Chip2(c.estado, AppTheme.estadoColor(c.estado)),
                ]),
                const SizedBox(height: 12),
                Animado(child: TimelineEstado(c.estado)),
                const SizedBox(height: 10),
                _fila(Icons.person, 'Cliente', c.cliente?['nombre'] ?? '-'),
                _fila(Icons.directions_car, 'Vehículo', c.vehiculoTexto),
                _fila(Icons.event, 'Fecha', '${fechaBonita(c.fecha)} ${c.hora}'),
                _fila(Icons.place, 'Dirección', c.direccion),
                _fila(Icons.payments, 'Precio', bs(c.precioTotal)),
                if (c.estado == 'Finalizada') _fila(Icons.savings, 'Tu ganancia', bs(c.gananciaLavador)),
                if (c.observacionCliente != null) _fila(Icons.notes, 'Notas del cliente', c.observacionCliente!),
                const SizedBox(height: 12),
                if (c.tieneUbicacion) ...[
                  MapaVista(alto: 220, marcadores: [MarcadorMapa(LatLng(c.latitud!, c.longitud!), Icons.location_on, Colors.red)]),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(onPressed: () => _navegar(c), icon: const Icon(Icons.navigation), label: const Text('Abrir navegación')),
                ],
                if (c.cliente?['telefono'] != null)
                  OutlinedButton.icon(onPressed: () => launchUrl(Uri.parse('tel:${c.cliente!['telefono']}')), icon: const Icon(Icons.call), label: const Text('Llamar al cliente')),
                const SizedBox(height: 16),
                if (c.estado == 'Aceptada')
                  ElevatedButton.icon(onPressed: _trabajando ? null : () => _accion(() => Repo.enCamino(c.id), 'Marcado En camino.'), icon: const Icon(Icons.directions_run), label: const Text('Voy en camino')),
                if (c.estado == 'En camino')
                  ElevatedButton.icon(onPressed: _trabajando ? null : () => _accion(() => Repo.enProceso(c.id), 'Lavado en proceso.'), icon: const Icon(Icons.cleaning_services), label: const Text('Iniciar lavado')),
                if (c.activa) ...[
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: _trabajando ? null : () => _finalizar(c),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Finalizar lavado'),
                  ),
                ],
              ]),
            ),
    ));
  }
}
