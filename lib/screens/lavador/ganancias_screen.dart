import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/repository.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

class GananciasScreen extends StatefulWidget {
  const GananciasScreen({super.key});
  @override
  State<GananciasScreen> createState() => GananciasScreenState();
}

class GananciasScreenState extends State<GananciasScreen> {
  late Future<Ganancias> _f = Repo.ganancias();
  void recargar() => setState(() => _f = Repo.ganancias());
  void _recargar() => recargar();

  Widget _kpi(String t, double v) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(children: [Text(bs(v), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), Text(t, style: const TextStyle(fontSize: 12))]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Ganancias>(
      future: _f,
      builder: (c, s) {
        if (s.connectionState != ConnectionState.done) return const Cargando();
        if (s.hasError) return VistaError(s.error.toString(), _recargar);
        final g = s.data!;
        return RefreshIndicator(
          onRefresh: () async => _recargar(),
          child: ListView(padding: const EdgeInsets.all(12), children: [
            Row(children: [_kpi('Hoy', g.hoy), _kpi('Semana', g.semana), _kpi('Mes', g.mes)]),
            Card(
              child: ListTile(
                leading: const Icon(Icons.account_balance_wallet, color: Colors.green),
                title: Text('Total acumulado: ${bs(g.total)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${g.servicios} servicios realizados'),
              ),
            ),
            const Padding(padding: EdgeInsets.fromLTRB(8, 12, 8, 4), child: Text('Últimos servicios', style: TextStyle(fontWeight: FontWeight.bold))),
            if (g.ultimos.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Vacio('Aún no tienes servicios finalizados')),
            for (final u in g.ultimos)
              Card(
                child: ListTile(
                  title: Text('${u['servicio'] ?? '-'}'),
                  subtitle: Text('${u['cliente'] ?? ''}\n${u['finalizado_at'] == null ? '' : DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(u['finalizado_at']).toLocal())}'),
                  isThreeLine: true,
                  trailing: Text('+ ${bs((u['ganancia_lavador'] as num).toDouble())}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ),
              ),
          ]),
        );
      },
    );
  }
}
