import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/config.dart';
import '../../core/repository.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/fondo.dart';

class InicioLavador extends StatefulWidget {
  /// Se llama con `true` cuando el lavador queda conectado/ocupado (compartir GPS).
  final void Function(bool compartirGps) onEstadoCambio;
  final void Function(int tab) onIrA;
  const InicioLavador({super.key, required this.onEstadoCambio, required this.onIrA});
  @override
  State<InicioLavador> createState() => InicioLavadorState();
}

class InicioLavadorState extends State<InicioLavador> {
  Map<String, dynamic>? _p;
  String? _error;
  bool _trabajando = false;

  @override
  void initState() {
    super.initState();
    recargar();
  }

  Future<void> recargar() async {
    try {
      final p = await Repo.perfilLavador();
      final estado = p['estado_disponibilidad'];
      widget.onEstadoCambio(estado == 'Disponible' || estado == 'Ocupado');
      if (mounted) setState(() { _p = p; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _toggle(bool conectar) async {
    HapticFeedback.mediumImpact();
    setState(() => _trabajando = true);
    try {
      conectar ? await Repo.conectar() : await Repo.desconectar();
      await recargar();
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  Widget _kpi(String t, String v, IconData i, List<Color> colores, int tab, int delay) => Expanded(
        child: Animado(
          delayMs: delay,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onIrA(tab);
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colores, begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: colores.last.withOpacity(.35), blurRadius: 12, offset: const Offset(0, 6))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(i, color: Colors.white70, size: 28),
                const SizedBox(height: 10),
                Text(v, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
                Text(t, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
            ),
          ),
        ),
      );

  Widget _accion(String t, IconData i, int tab) => Expanded(
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onIrA(tab);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Column(children: [
                Icon(i, size: 30, color: AppTheme.primary),
                const SizedBox(height: 6),
                Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (_p == null) return _error != null ? VistaError(_error!, recargar) : const Cargando();
    final p = _p!;
    final aprobado = p['estado_aprobacion'] == 'Aprobado';
    final disp = p['estado_disponibilidad'] as String;
    final conectado = disp == 'Disponible';
    final ocupado = disp == 'Ocupado';
    final color = conectado ? const Color(0xFF22C55E) : ocupado ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8);
    final puedeConectar = p['puede_conectarse'] == true;
    final puedeToggle = puedeConectar || p['puede_desconectarse'] == true;
    final fotoPerfil = p['foto_perfil_url'] as String?;

    return RefreshIndicator(
      onRefresh: recargar,
      child: ListView(padding: EdgeInsets.zero, children: [
        // ---------- Cabecera ----------
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
          decoration: const BoxDecoration(
            gradient: AppTheme.gradient,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
          ),
          child: Column(children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Hola, ${p['nombre']} 👋', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(aprobado ? 'Listo para recibir servicios' : 'Cuenta: ${p['estado_aprobacion']}', style: const TextStyle(color: Colors.white70)),
                ]),
              ),
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white24,
                backgroundImage: fotoPerfil == null ? null : NetworkImage(fotoPerfil),
                child: fotoPerfil == null ? const Icon(Icons.person, color: Colors.white) : null,
              ),
            ]),
            const SizedBox(height: 26),
            // Botón grande de conexión
            GestureDetector(
              onTap: (puedeToggle && !_trabajando) ? () => _toggle(puedeConectar) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOut,
                width: 158,
                height: 158,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: color, width: 7),
                  boxShadow: [BoxShadow(color: color.withOpacity(.65), blurRadius: conectado ? 42 : 12, spreadRadius: conectado ? 8 : 0)],
                ),
                child: _trabajando
                    ? Center(child: CircularProgressIndicator(color: color))
                    : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.power_settings_new, size: 60, color: color),
                        Text(disp, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
                      ]),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              !aprobado
                  ? 'Un administrador debe aprobar tu cuenta'
                  : ocupado
                      ? 'Tienes un servicio en curso'
                      : conectado
                          ? 'Toca para desconectarte'
                          : 'Toca para conectarte y recibir solicitudes',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
            if (disp != 'Desconectado')
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.gps_fixed, size: 14, color: Colors.lightGreenAccent),
                  const SizedBox(width: 4),
                  Text('Compartiendo ubicación cada ${AppConfig.gpsIntervalSeconds} s (app abierta)', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ),
          ]),
        ),

        // ---------- Contenido ----------
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            if (!aprobado)
              Animado(
                child: Card(
                  color: Colors.orange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      const Icon(Icons.info, color: Colors.deepOrange),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Tu cuenta está "${p['estado_aprobacion']}". Podrás recibir solicitudes cuando sea aprobada.', style: const TextStyle(color: Colors.deepOrange))),
                    ]),
                  ),
                ),
              ),
            Row(children: [
              _kpi('Citas de hoy', '${p['citas_hoy']}', Icons.today, const [Color(0xFF6366F1), Color(0xFF8B5CF6)], 2, 100),
              const SizedBox(width: 12),
              _kpi('Ganancia hoy', bs((p['ganancia_hoy'] as num).toDouble()), Icons.attach_money, const [Color(0xFF10B981), Color(0xFF059669)], 3, 220),
            ]),
            const SizedBox(height: 14),
            Animado(
              delayMs: 340,
              child: Row(children: [
                _accion('Solicitudes', Icons.notifications_active, 1),
                _accion('Mis citas', Icons.assignment, 2),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}
