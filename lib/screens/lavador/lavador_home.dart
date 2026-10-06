import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/config.dart';
import '../../core/location.dart';
import '../../core/repository.dart';
import '../../widgets/common.dart';
import '../../widgets/fondo.dart';
import '../shared/notificaciones_screen.dart';
import '../shared/perfil_screen.dart';
import 'ganancias_screen.dart';
import 'inicio_lavador.dart';
import 'mis_citas_screen.dart';
import 'solicitudes_screen.dart';

class LavadorHome extends StatefulWidget {
  const LavadorHome({super.key});
  @override
  State<LavadorHome> createState() => _LavadorHomeState();
}

class _LavadorHomeState extends State<LavadorHome> {
  int _tab = 0;
  int _noLeidas = 0;
  Timer? _gps;
  bool _compartiendo = false;
  final _inicioKey = GlobalKey<InicioLavadorState>();
  final _solicitudesKey = GlobalKey<SolicitudesScreenState>();
  final _misCitasKey = GlobalKey<MisCitasScreenState>();
  final _gananciasKey = GlobalKey<GananciasScreenState>();

  static const _titulos = ['Inicio', 'Solicitudes', 'Mis citas', 'Ganancias', 'Mi perfil'];

  @override
  void initState() {
    super.initState();
    _contador();
  }

  @override
  void dispose() {
    _gps?.cancel();
    super.dispose();
  }

  Future<void> _contador() async {
    try {
      final n = await Repo.contadorNotificaciones();
      if (mounted) setState(() => _noLeidas = n);
    } catch (_) {}
  }

  /// Inicia/detiene el envío periódico de ubicación (mientras la app está abierta).
  void _controlarGps(bool activo) {
    if (activo && _gps == null) {
      _enviarUbicacion();
      _gps = Timer.periodic(const Duration(seconds: AppConfig.gpsIntervalSeconds), (_) => _enviarUbicacion());
      if (mounted) setState(() => _compartiendo = true);
    } else if (!activo && _gps != null) {
      _gps!.cancel();
      _gps = null;
      if (mounted) setState(() => _compartiendo = false);
    }
  }

  Future<void> _enviarUbicacion() async {
    try {
      final p = await LocationHelper.actual();
      await Repo.enviarUbicacion(p.latitude, p.longitude);
    } catch (_) {/* se reintenta en el siguiente ciclo */}
  }

  /// Cambia de pestaña y refresca los datos de esa pantalla.
  void _irA(int i) {
    setState(() => _tab = i);
    if (i == 0) _inicioKey.currentState?.recargar();
    if (i == 1) _solicitudesKey.currentState?.recargar();
    if (i == 2) _misCitasKey.currentState?.recargar();
    if (i == 3) _gananciasKey.currentState?.recargar();
    _contador();
  }

  @override
  Widget build(BuildContext context) {
    final paginas = [
      InicioLavador(key: _inicioKey, onEstadoCambio: _controlarGps, onIrA: _irA),
      SolicitudesScreen(
        key: _solicitudesKey,
        onAceptada: (id) {
          _irA(2);
          // Abre directo la cita aceptada para ver ubicación y cambiar estado.
          WidgetsBinding.instance.addPostFrameCallback((_) => _misCitasKey.currentState?.abrirCita(id));
        },
      ),
      MisCitasScreen(key: _misCitasKey, onFinalizada: () => _irA(0)),
      GananciasScreen(key: _gananciasKey),
      const PerfilScreen(),
    ];

    return FondoApp(child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: const GradientBar(),
        title: Text(_titulos[_tab], style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_compartiendo) const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.gps_fixed, color: Colors.lightGreenAccent)),
          IconButton(
            icon: Badge(isLabelVisible: _noLeidas > 0, label: Text('$_noLeidas'), child: const Icon(Icons.notifications)),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificacionesScreen()));
              _contador();
            },
          ),
        ],
      ),
      body: IndexedStack(index: _tab, children: paginas),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _irA,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.notifications_active), label: 'Solicitudes'),
          NavigationDestination(icon: Icon(Icons.assignment), label: 'Mis citas'),
          NavigationDestination(icon: Icon(Icons.attach_money), label: 'Ganancias'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    ));
  }
}
