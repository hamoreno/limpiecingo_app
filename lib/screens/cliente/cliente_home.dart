import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/repository.dart';
import '../../core/sync_service.dart';
import '../../widgets/banner_offline.dart';
import '../../widgets/common.dart';
import '../../widgets/fondo.dart';
import '../shared/chat_screen.dart';
import '../shared/notificaciones_screen.dart';
import '../shared/perfil_screen.dart';
import 'citas_screen.dart';
import 'nueva_cita_screen.dart';
import 'vehiculos_screen.dart';

class ClienteHome extends StatefulWidget {
  const ClienteHome({super.key});
  @override
  State<ClienteHome> createState() => _ClienteHomeState();
}

class _ClienteHomeState extends State<ClienteHome> {
  int _tab = 0;
  int _noLeidas = 0;
  final _citasKey = GlobalKey<CitasScreenState>();
  final _vehiculosKey = GlobalKey<VehiculosScreenState>();

  static const _titulos = ['Mis citas', 'Mis vehículos', 'Asistente Cingo', 'Mi perfil'];

  Timer? _sync;

  @override
  void initState() {
    super.initState();
    _cargarContador();
    _sincronizar();
    // Cada 30 s intenta enviar lo que se guardó sin conexión.
    _sync = Timer.periodic(const Duration(seconds: 30), (_) => _sincronizar());
  }

  @override
  void dispose() {
    _sync?.cancel();
    super.dispose();
  }

  Future<void> _sincronizar() async {
    await SyncService.refrescarContador();
    final r = await SyncService.sincronizar();
    if (!mounted) return;
    if (r.enviados > 0) {
      snack(context, '${r.enviados} registro(s) sincronizado(s) con el servidor.');
      _citasKey.currentState?.recargar();
      _vehiculosKey.currentState?.recargar();
    }
    if (r.descartados > 0) {
      snack(context, '${r.descartados} registro(s) fueron rechazados por el servidor (duplicados o datos inválidos).', error: true);
    }
  }

  Future<void> _cargarContador() async {
    try {
      final n = await Repo.contadorNotificaciones();
      if (mounted) setState(() => _noLeidas = n);
    } catch (_) {}
  }

  Future<void> _nuevaCita() async {
    final creada = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const NuevaCitaScreen()));
    if (creada == true) _citasKey.currentState?.recargar();
  }

  @override
  Widget build(BuildContext context) {
    final paginas = [CitasScreen(key: _citasKey), VehiculosScreen(key: _vehiculosKey), const ChatScreen(), const PerfilScreen()];

    return FondoApp(child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: const GradientBar(),
        title: Text(_titulos[_tab], style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Badge(isLabelVisible: _noLeidas > 0, label: Text('$_noLeidas'), child: const Icon(Icons.notifications)),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificacionesScreen()));
              _cargarContador();
            },
          ),
        ],
      ),
      body: Column(children: [
        const BannerOffline(),
        Expanded(child: IndexedStack(index: _tab, children: paginas)),
      ]),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(onPressed: _nuevaCita, icon: const Icon(Icons.add), label: const Text('Solicitar lavado'))
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          setState(() => _tab = i);
          // Al entrar a una pestaña se piden los datos otra vez.
          if (i == 0) _citasKey.currentState?.recargar();
          if (i == 1) _vehiculosKey.currentState?.recargar();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.event_note), label: 'Citas'),
          NavigationDestination(icon: Icon(Icons.directions_car), label: 'Vehículos'),
          NavigationDestination(icon: Icon(Icons.smart_toy), label: 'Cingo'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    ));
  }
}
