import 'package:flutter/material.dart';
import '../../core/repository.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import 'cita_detalle_screen.dart';

class CitasScreen extends StatefulWidget {
  const CitasScreen({super.key});
  @override
  State<CitasScreen> createState() => CitasScreenState();
}

class CitasScreenState extends State<CitasScreen> {
  late Future<List<Cita>> _f = Repo.citasCliente();

  void recargar() => setState(() => _f = Repo.citasCliente());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Cita>>(
      future: _f,
      builder: (c, s) {
        if (s.connectionState != ConnectionState.done) return const Cargando();
        if (s.hasError) return VistaError(s.error.toString(), recargar);
        final l = s.data!;
        if (l.isEmpty) return const Vacio('Aún no tienes citas.\nToca "Solicitar lavado".', icono: Icons.local_car_wash);
        return RefreshIndicator(
          onRefresh: () async => recargar(),
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 90),
            itemCount: l.length,
            itemBuilder: (_, i) {
              final cita = l[i];
              return CitaCard(
                cita: cita,
                trailingExtra: cita.estado == 'Finalizada'
                    ? Chip2('Pago: ${cita.estadoPago ?? 'Pendiente'}', _pagoColor(cita.estadoPago))
                    : null,
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => CitaDetalleScreen(citaId: cita.id)));
                  recargar();
                },
              );
            },
          ),
        );
      },
    );
  }

  Color _pagoColor(String? e) => e == 'Pagado' ? Colors.green : e == 'En revisión' ? Colors.blue : e == 'Observado' ? Colors.red : Colors.orange;
}
