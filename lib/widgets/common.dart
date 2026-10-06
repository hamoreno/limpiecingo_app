import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../models/models.dart';
import 'fondo.dart';

void snack(BuildContext c, String msg, {bool error = false}) {
  ScaffoldMessenger.of(c)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? Colors.red.shade700 : null));
}

String bs(double v) => 'Bs ${NumberFormat('#,##0.00').format(v)}';

String fechaBonita(String yyyyMmDd) {
  final d = DateTime.tryParse(yyyyMmDd);
  return d == null ? yyyyMmDd : DateFormat('dd/MM/yyyy').format(d);
}

class Chip2 extends StatelessWidget {
  final String text;
  final Color color;
  const Chip2(this.text, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
      );
}

class Cargando extends StatelessWidget {
  const Cargando({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

class VistaError extends StatelessWidget {
  final String mensaje;
  final VoidCallback onReintentar;
  const VistaError(this.mensaje, this.onReintentar, {super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 8),
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onReintentar, child: const Text('Reintentar')),
          ]),
        ),
      );
}

class Vacio extends StatelessWidget {
  final String texto;
  final IconData icono;
  const Vacio(this.texto, {super.key, this.icono = Icons.inbox_outlined});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icono, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(texto, style: TextStyle(color: Colors.grey.shade600)),
        ]),
      );
}

/// Tarjeta resumen de una cita (la usan cliente y lavador).
class CitaCard extends StatelessWidget {
  final Cita cita;
  final VoidCallback onTap;
  final bool mostrarCliente;
  final Widget? trailingExtra;
  const CitaCard({super.key, required this.cita, required this.onTap, this.mostrarCliente = false, this.trailingExtra});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.estadoColor(cita.estado);
    return Animado(
      dy: 16,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        clipBehavior: Clip.antiAlias,
        elevation: 3,
        shadowColor: color.withOpacity(.25),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(width: 6, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: color.withOpacity(.12),
                        child: Icon(Icons.local_car_wash, color: color),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(cita.servicioNombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                      Chip2(cita.estado, color),
                    ]),
                    const SizedBox(height: 10),
                    if (mostrarCliente && cita.cliente != null)
                      _linea(Icons.person, '${cita.cliente!['nombre']}'),
                    _linea(Icons.directions_car, cita.vehiculoTexto),
                    _linea(Icons.event, '${fechaBonita(cita.fecha)}  ${cita.hora}'),
                    _linea(Icons.place, cita.direccion, maxLines: 1),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(child: trailingExtra ?? const SizedBox()),
                      Text(bs(cita.precioTotal), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppTheme.primary)),
                    ]),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _linea(IconData i, String t, {int maxLines = 2}) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(children: [
          Icon(i, size: 15, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Expanded(child: Text(t, maxLines: maxLines, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
        ]),
      );
}

/// Diálogo de confirmación simple.
Future<bool> confirmar(BuildContext c, String titulo, String texto) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (_) => AlertDialog(
      title: Text(titulo),
      content: Text(texto),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sí')),
      ],
    ),
  );
  return r == true;
}
