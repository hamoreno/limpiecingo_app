import 'package:flutter/material.dart';
import '../core/sync_service.dart';

/// Franja que avisa cuando no hay conexión o hay datos por sincronizar.
class BannerOffline extends StatelessWidget {
  const BannerOffline({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SyncService.offline,
      builder: (_, off, __) => ValueListenableBuilder<int>(
        valueListenable: SyncService.pendientes,
        builder: (_, n, __) {
          if (!off && n == 0) return const SizedBox.shrink();
          final texto = off
              ? 'Sin conexión · mostrando datos guardados${n > 0 ? ' · $n pendiente(s)' : ''}'
              : 'Sincronizando $n pendiente(s)…';
          return Material(
            color: off ? Colors.orange.shade700 : Colors.blue.shade600,
            child: SafeArea(
              bottom: false,
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Row(children: [
                  Icon(off ? Icons.cloud_off : Icons.sync, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(texto, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}
