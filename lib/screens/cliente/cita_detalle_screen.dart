import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config.dart';
import '../../core/repository.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import '../../widgets/fondo.dart';
import '../../widgets/mapa.dart';

class CitaDetalleScreen extends StatefulWidget {
  final int citaId;
  const CitaDetalleScreen({super.key, required this.citaId});
  @override
  State<CitaDetalleScreen> createState() => _CitaDetalleScreenState();
}

class _CitaDetalleScreenState extends State<CitaDetalleScreen> {
  Cita? _cita;
  Map<String, dynamic>? _ubic; // ubicación del lavador
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _cargar();
    // Refresca estado y ubicación mientras la pantalla está abierta.
    _timer = Timer.periodic(const Duration(seconds: AppConfig.trackingIntervalSeconds), (_) => _cargar(silencioso: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cargar({bool silencioso = false}) async {
    try {
      final c = await Repo.citaCliente(widget.citaId);
      Map<String, dynamic>? u;
      if (c.lavador != null && (c.estado == 'Aceptada' || c.estado == 'En camino' || c.estado == 'En proceso')) {
        u = await Repo.ubicacionLavador(c.id);
      }
      if (mounted) setState(() { _cita = c; _ubic = u; _error = null; });
    } catch (e) {
      if (!silencioso && mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _accion(Future<void> Function() f, String ok) async {
    try {
      await f();
      if (mounted) snack(context, ok);
      await _cargar();
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    }
  }

  Future<void> _pagar(Cita c) async {
    final res = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _PagoSheet(cita: c),
      ),
    );
    if (res == true) await _cargar();
  }

  Future<void> _evaluar(Cita c) async {
    final res = await showDialog<bool>(context: context, builder: (_) => _EncuestaDialog(citaId: c.id));
    if (res == true) await _cargar();
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
                _fila(Icons.directions_car, 'Vehículo', c.vehiculoTexto),
                _fila(Icons.event, 'Fecha', '${fechaBonita(c.fecha)} ${c.hora}'),
                _fila(Icons.place, 'Dirección', c.direccion),
                _fila(Icons.payments, 'Precio', bs(c.precioTotal)),
                if (c.observacionCliente != null) _fila(Icons.notes, 'Notas', c.observacionCliente!),
                const SizedBox(height: 12),

                // ---- Mapa / seguimiento ----
                if (c.tieneUbicacion)
                  MapaVista(alto: 240, marcadores: [
                    MarcadorMapa(LatLng(c.latitud!, c.longitud!), Icons.location_on, Colors.red),
                    if (_ubic != null)
                      MarcadorMapa(LatLng(_ubic!['latitud'], _ubic!['longitud']), Icons.directions_car, AppTheme.primary),
                  ]),
                if (c.lavador != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(c.lavador!['nombre'] ?? 'Lavador'),
                      subtitle: Text(_ubic == null ? 'Aún no comparte su ubicación' : 'Ubicación en vivo activa'),
                      trailing: c.lavador!['telefono'] == null
                          ? null
                          : IconButton(icon: const Icon(Icons.call, color: Colors.green), onPressed: () => launchUrl(Uri.parse('tel:${c.lavador!['telefono']}'))),
                    ),
                  ),
                ],

                // ---- Pago ----
                if (c.estado == 'Finalizada') ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Text('Pago', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const Spacer(),
                          Chip2(c.estadoPago ?? 'Pendiente', AppTheme.pagoColor(c.estadoPago)),
                        ]),
                        if (c.metodoPago != null) Text('Método: ${c.metodoPago}'),
                        if (c.estadoPago == 'Observado' && c.observacionPago != null)
                          Padding(padding: const EdgeInsets.only(top: 6), child: Text('Observación del administrador: ${c.observacionPago}', style: const TextStyle(color: Colors.red))),
                        if (c.puedePagar) ...[
                          const SizedBox(height: 10),
                          ElevatedButton.icon(onPressed: () => _pagar(c), icon: const Icon(Icons.upload_file), label: Text(c.estadoPago == 'Observado' ? 'Volver a enviar comprobante' : 'Pagar / subir comprobante')),
                        ],
                        if (c.estadoPago == 'En revisión') const Padding(padding: EdgeInsets.only(top: 8), child: Text('Tu comprobante está siendo revisado por el administrador.')),
                      ]),
                    ),
                  ),
                ],

                if (c.puedeEvaluar) ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(onPressed: () => _evaluar(c), icon: const Icon(Icons.star), label: const Text('Calificar el servicio')),
                ],
                if (c.encuestaRespondida)
                  Padding(padding: const EdgeInsets.only(top: 12), child: Center(child: Text('Tu calificación: ${'★' * (c.encuestaCalificacion ?? 0)}', style: const TextStyle(fontSize: 18, color: Colors.amber)))),

                if (c.puedeCancelar) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    icon: const Icon(Icons.cancel),
                    label: const Text('Cancelar solicitud'),
                    onPressed: () async {
                      if (await confirmar(context, 'Cancelar', '¿Cancelar esta solicitud?')) {
                        await _accion(() => Repo.cancelarCita(c.id), 'Cita cancelada.');
                      }
                    },
                  ),
                ],
              ]),
            ),
    ));
  }
}

class _PagoSheet extends StatefulWidget {
  final Cita cita;
  const _PagoSheet({required this.cita});
  @override
  State<_PagoSheet> createState() => _PagoSheetState();
}

class _PagoSheetState extends State<_PagoSheet> {
  String _metodo = 'Transferencia bancaria';
  String? _ruta;
  final _obs = TextEditingController();
  bool _enviando = false;

  Future<void> _elegir() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1800);
    if (x != null) setState(() => _ruta = x.path);
  }

  Future<void> _enviar() async {
    if (_ruta == null) {
      snack(context, 'Adjunta el comprobante de pago.', error: true);
      return;
    }
    setState(() => _enviando = true);
    try {
      await Repo.pagarCita(widget.cita.id, _metodo, _ruta!, _obs.text.trim());
      if (mounted) {
        Navigator.pop(context, true);
        snack(context, 'Comprobante enviado. Tu pago está en revisión.');
      }
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.cita.servicio ?? {};
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Pagar ${bs(widget.cita.precioTotal)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'Transferencia bancaria', label: Text('Transferencia'), icon: Icon(Icons.account_balance)),
            ButtonSegment(value: 'QR', label: Text('QR'), icon: Icon(Icons.qr_code)),
          ],
          selected: {_metodo},
          onSelectionChanged: (v) => setState(() => _metodo = v.first),
        ),
        const SizedBox(height: 12),
        if (_metodo == 'QR')
          (s['qr_pago_url'] != null)
              ? Center(child: Image.network(s['qr_pago_url'], height: 220, errorBuilder: (_, __, ___) => const Text('No se pudo cargar el QR.')))
              : const Text('Este servicio no tiene QR configurado.')
        else ...[
          Text('Banco: ${s['banco'] ?? '-'}'),
          Text('N° de cuenta: ${s['numero_cuenta'] ?? '-'}'),
          Text('Titular: ${s['titular_cuenta'] ?? '-'}'),
        ],
        const SizedBox(height: 14),
        OutlinedButton.icon(onPressed: _elegir, icon: Icon(_ruta == null ? Icons.attach_file : Icons.check_circle, color: _ruta == null ? null : Colors.green), label: Text(_ruta == null ? 'Adjuntar comprobante' : 'Comprobante adjuntado')),
        const SizedBox(height: 10),
        TextField(controller: _obs, decoration: const InputDecoration(labelText: 'Observación (opcional)')),
        const SizedBox(height: 14),
        ElevatedButton(onPressed: _enviando ? null : _enviar, child: Text(_enviando ? 'Enviando…' : 'Enviar comprobante')),
      ]),
    );
  }
}

class _EncuestaDialog extends StatefulWidget {
  final int citaId;
  const _EncuestaDialog({required this.citaId});
  @override
  State<_EncuestaDialog> createState() => _EncuestaDialogState();
}

class _EncuestaDialogState extends State<_EncuestaDialog> {
  int _n = 5;
  final _txt = TextEditingController();
  bool _enviando = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('¿Cómo estuvo el servicio?'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 1; i <= 5; i++)
            IconButton(onPressed: () => setState(() => _n = i), icon: Icon(i <= _n ? Icons.star : Icons.star_border, color: Colors.amber, size: 32)),
        ]),
        TextField(controller: _txt, maxLines: 3, decoration: const InputDecoration(labelText: 'Comentario (opcional)')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Luego')),
        TextButton(
          onPressed: _enviando
              ? null
              : () async {
                  setState(() => _enviando = true);
                  try {
                    await Repo.enviarEncuesta(widget.citaId, _n, _txt.text.trim());
                    if (context.mounted) Navigator.pop(context, true);
                  } catch (e) {
                    if (context.mounted) {
                      snack(context, e.toString(), error: true);
                      setState(() => _enviando = false);
                    }
                  }
                },
          child: const Text('Enviar'),
        ),
      ],
    );
  }
}
