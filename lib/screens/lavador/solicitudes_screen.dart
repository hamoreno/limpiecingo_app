import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/repository.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

class SolicitudesScreen extends StatefulWidget {
  /// Se llama con el id de la cita cuando el lavador la acepta correctamente.
  final void Function(int citaId)? onAceptada;
  const SolicitudesScreen({super.key, this.onAceptada});
  @override
  State<SolicitudesScreen> createState() => SolicitudesScreenState();
}

class SolicitudesScreenState extends State<SolicitudesScreen> {
  List<Cita>? _lista;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    recargar();
    // Revisa solicitudes nuevas automáticamente cada 10 segundos.
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => recargar(silencioso: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Se puede llamar desde fuera (al entrar a la pestaña).
  Future<void> recargar({bool silencioso = false}) async {
    try {
      final l = await Repo.solicitudes();
      if (mounted) setState(() { _lista = l; _error = null; });
    } catch (e) {
      // En refrescos automáticos no pisamos la lista con un error pasajero.
      if (!silencioso && mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _aceptar(Cita c) async {
    if (!await confirmar(context, 'Aceptar solicitud', '¿Aceptar ${c.servicioNombre} para el ${fechaBonita(c.fecha)} a las ${c.hora}?')) return;
    try {
      await Repo.aceptarSolicitud(c.id);
      if (mounted) snack(context, 'Solicitud aceptada.');
      await recargar();
      widget.onAceptada?.call(c.id);
      return;
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    }
    recargar();
  }

  @override
  Widget build(BuildContext context) {
    if (_lista == null) {
      return _error != null ? VistaError(_error!, recargar) : const Cargando();
    }
    final l = _lista!;
    return RefreshIndicator(
      onRefresh: recargar,
      child: l.isEmpty
          ? ListView(children: const [
              SizedBox(height: 160),
              Vacio('No hay solicitudes pendientes\n(se actualiza solo cada 10 s)', icono: Icons.notifications_off),
            ])
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              itemCount: l.length,
              itemBuilder: (_, i) {
                final c = l[i];
                return CitaCard(
                  cita: c,
                  mostrarCliente: true,
                  onTap: () {},
                  trailingExtra: Row(children: [
                    if (c.tieneChoque)
                      const Expanded(child: Text('Choca con otra cita tuya', style: TextStyle(color: Colors.red, fontSize: 12)))
                    else
                      const Spacer(),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(minimumSize: const Size(100, 38)),
                      onPressed: c.tieneChoque ? null : () => _aceptar(c),
                      child: const Text('Aceptar'),
                    ),
                  ]),
                );
              },
            ),
    );
  }
}
