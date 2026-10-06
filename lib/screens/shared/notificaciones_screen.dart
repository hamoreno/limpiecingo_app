import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/repository.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key});
  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  late Future<List<Notificacion>> _f = Repo.notificaciones();

  void _recargar() => setState(() => _f = Repo.notificaciones());

  IconData _icono(String t) => t == 'success' ? Icons.check_circle : t == 'warning' ? Icons.warning_amber : Icons.info;
  Color _color(String t) => t == 'success' ? Colors.green : t == 'warning' ? Colors.orange : Colors.blue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones'), actions: [
        IconButton(
          tooltip: 'Marcar todas como leídas',
          icon: const Icon(Icons.done_all),
          onPressed: () async {
            await Repo.leerTodasNotificaciones();
            _recargar();
          },
        ),
      ]),
      body: FutureBuilder<List<Notificacion>>(
        future: _f,
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) return const Cargando();
          if (s.hasError) return VistaError(s.error.toString(), _recargar);
          final l = s.data!;
          if (l.isEmpty) return const Vacio('No tienes notificaciones', icono: Icons.notifications_none);
          return RefreshIndicator(
            onRefresh: () async => _recargar(),
            child: ListView.separated(
              itemCount: l.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final n = l[i];
                return ListTile(
                  tileColor: n.leida ? null : Colors.blue.withOpacity(.06),
                  leading: Icon(_icono(n.tipo), color: _color(n.tipo)),
                  title: Text(n.titulo, style: TextStyle(fontWeight: n.leida ? FontWeight.normal : FontWeight.bold)),
                  subtitle: Text('${n.mensaje}\n${DateFormat('dd/MM HH:mm').format(n.fecha.toLocal())}'),
                  isThreeLine: true,
                  onTap: () async {
                    if (!n.leida) {
                      await Repo.leerNotificacion(n.id);
                      _recargar();
                    }
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
