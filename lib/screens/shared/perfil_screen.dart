import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common.dart';

class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final u = context.watch<AuthProvider>().user!;
    final p = u.perfil;
    return ListView(padding: const EdgeInsets.all(20), children: [
      const CircleAvatar(radius: 44, child: Icon(Icons.person, size: 48)),
      const SizedBox(height: 12),
      Center(child: Text('${p['nombre'] ?? u.name} ${p['apellido'] ?? ''}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
      Center(child: Text(u.email)),
      Center(child: Padding(padding: const EdgeInsets.only(top: 6), child: Chip(label: Text(u.rol)))),
      const SizedBox(height: 16),
      if (p['telefono'] != null) ListTile(leading: const Icon(Icons.phone), title: Text('${p['telefono']}')),
      if (p['direccion'] != null) ListTile(leading: const Icon(Icons.home), title: Text('${p['direccion']}')),
      if (u.esLavador) ListTile(leading: const Icon(Icons.verified_user), title: const Text('Estado de aprobación'), subtitle: Text('${p['estado_aprobacion'] ?? '-'}')),
      const SizedBox(height: 20),
      OutlinedButton.icon(
        icon: const Icon(Icons.logout),
        label: const Text('Cerrar sesión'),
        onPressed: () async {
          if (await confirmar(context, 'Cerrar sesión', '¿Seguro que deseas salir?')) {
            if (context.mounted) await context.read<AuthProvider>().logout();
          }
        },
      ),
    ]);
  }
}
