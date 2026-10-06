import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Fondo de la app: la foto de Limpiecingo muy suave detrás del contenido.
class FondoApp extends StatelessWidget {
  final Widget child;
  const FondoApp({super.key, required this.child});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: Color(0xFFF5F8FA),
      image: DecorationImage(
        image: ResizeImage(AssetImage('assets/images/fondo.jpg'), width: 480),
        fit: BoxFit.cover,
        colorFilter: ColorFilter.mode(Color(0xE3F5F8FA), BlendMode.srcOver),
      ),
    ),
    child: child,
  );
}

/// Degradado para usar dentro de AppBar.flexibleSpace.
class GradientBar extends StatelessWidget {
  const GradientBar({super.key});
  @override
  Widget build(BuildContext context) =>
      Container(decoration: const BoxDecoration(gradient: AppTheme.gradient));
}

PreferredSizeWidget gradAppBar(String title, {List<Widget>? actions}) => AppBar(
  title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
  actions: actions,
  backgroundColor: Colors.transparent,
  elevation: 0,
  scrolledUnderElevation: 0,
  flexibleSpace: const GradientBar(),
);

/// Entrada animada: aparece con fundido y deslizándose hacia arriba.
class Animado extends StatelessWidget {
  final Widget child;
  final int delayMs;
  final double dy;
  const Animado({super.key, required this.child, this.delayMs = 0, this.dy = 24});

  @override
  Widget build(BuildContext context) {
    final total = 450 + delayMs;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delayMs / total, 1, curve: Curves.easeOutCubic),
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * dy), child: c),
      ),
      child: child,
    );
  }
}

/// Línea de progreso del servicio: Aceptada → En camino → En proceso → Finalizada.
class TimelineEstado extends StatefulWidget {
  final String estado;
  const TimelineEstado(this.estado, {super.key});
  @override
  State<TimelineEstado> createState() => _TimelineEstadoState();
}

class _TimelineEstadoState extends State<TimelineEstado> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  static const _pasos = ['Aceptada', 'En camino', 'En proceso', 'Finalizada'];
  static const _iconos = [Icons.check, Icons.directions_car, Icons.cleaning_services, Icons.flag];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _mensaje(IconData i, Color c, String t) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: c.withOpacity(.1), borderRadius: BorderRadius.circular(14)),
    child: Row(children: [
      Icon(i, color: c),
      const SizedBox(width: 10),
      Expanded(child: Text(t, style: TextStyle(color: c, fontWeight: FontWeight.w600))),
    ]),
  );

  Widget _nodo(int i, int idx) {
    final hecho = i < idx || idx == 3;
    final actual = i == idx && idx < 3;
    final color = hecho ? Colors.green : (actual ? AppTheme.primary : Colors.grey.shade300);
    return SizedBox(
      width: 64,
      child: Column(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: actual
                ? [BoxShadow(color: AppTheme.primary.withOpacity(.5), blurRadius: 4 + 10 * _c.value, spreadRadius: 1 + 3 * _c.value)]
                : null,
          ),
          child: Icon(hecho ? Icons.check : _iconos[i], color: Colors.white, size: 20),
        ),
        const SizedBox(height: 4),
        Text(_pasos[i],
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, fontWeight: actual ? FontWeight.bold : FontWeight.normal, color: actual ? AppTheme.primary : Colors.black54)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.estado;
    if (e == 'Cancelada') return _mensaje(Icons.cancel, Colors.red, 'Esta cita fue cancelada');
    if (e == 'Pendiente') return _mensaje(Icons.hourglass_top, Colors.orange, 'Esperando que un lavador acepte la solicitud');
    final idx = _pasos.indexOf(e);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < 4; i++) ...[
              _nodo(i, idx),
              if (i < 3)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      height: 3,
                      decoration: BoxDecoration(color: i < idx ? Colors.green : Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                ),
            ],
          ]),
        ),
      ),
    );
  }
}
