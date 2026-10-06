import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/repository.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import 'lavador_cita_screen.dart';

class MisCitasScreen extends StatefulWidget {
  /// Se llama cuando el lavador finaliza una cita (para ir al Inicio).
  final VoidCallback? onFinalizada;
  const MisCitasScreen({super.key, this.onFinalizada});
  @override
  State<MisCitasScreen> createState() => MisCitasScreenState();
}

class MisCitasScreenState extends State<MisCitasScreen> {
  String _tipo = 'activas';
  List<Cita>? _lista;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    recargar();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => recargar(silencioso: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Se llama desde fuera al entrar a la pestaña o al aceptar una solicitud.
  Future<void> recargar({bool silencioso = false}) async {
    try {
      final l = await Repo.citasLavador(tipo: _tipo);
      if (mounted) setState(() { _lista = l; _error = null; });
    } catch (e) {
      if (!silencioso && mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _abrir(Cita c) => abrirCita(c.id);

  /// Abre directamente el detalle de una cita (la usa "Aceptar").
  Future<void> abrirCita(int id) async {
    final r = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => LavadorCitaScreen(citaId: id)));
    recargar();
    if (r == 'finalizada') widget.onFinalizada?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(10),
        child: SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'activas', label: Text('Activas')),
            ButtonSegment(value: 'historial', label: Text('Historial')),
          ],
          selected: {_tipo},
          onSelectionChanged: (s) {
            setState(() { _tipo = s.first; _lista = null; });
            recargar();
          },
        ),
      ),
      Expanded(
        child: _lista == null
            ? (_error != null ? VistaError(_error!, recargar) : const Cargando())
            : RefreshIndicator(
                onRefresh: recargar,
                child: _lista!.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 140),
                        Vacio('Sin citas en esta sección', icono: Icons.assignment_late),
                      ])
                    : ListView.builder(
                        itemCount: _lista!.length,
                        itemBuilder: (_, i) => CitaCard(
                          cita: _lista![i],
                          mostrarCliente: true,
                          onTap: () => _abrir(_lista![i]),
                        ),
                      ),
              ),
      ),
    ]);
  }
}
