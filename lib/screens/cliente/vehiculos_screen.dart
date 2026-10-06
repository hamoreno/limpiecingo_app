import 'package:flutter/material.dart';
import '../../core/repository.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

class VehiculosScreen extends StatefulWidget {
  const VehiculosScreen({super.key});
  @override
  State<VehiculosScreen> createState() => _VehiculosScreenState();
}

class _VehiculosScreenState extends State<VehiculosScreen> {
  late Future<List<Vehiculo>> _f = Repo.vehiculos();
  void _recargar() => setState(() => _f = Repo.vehiculos());

  Future<void> _abrirForm([Vehiculo? v]) async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => VehiculoForm(vehiculo: v)));
    if (ok == true) _recargar();
  }

  IconData _icono(String t) => t == 'Moto' ? Icons.two_wheeler : t == 'Camión' ? Icons.local_shipping : Icons.directions_car;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FutureBuilder<List<Vehiculo>>(
        future: _f,
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) return const Cargando();
          if (s.hasError) return VistaError(s.error.toString(), _recargar);
          final l = s.data!;
          if (l.isEmpty) return const Vacio('No tienes vehículos registrados', icono: Icons.directions_car);
          return RefreshIndicator(
            onRefresh: () async => _recargar(),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
              itemCount: l.length,
              itemBuilder: (_, i) {
                final v = l[i];
                return Card(
                  child: ListTile(
                    leading: Icon(_icono(v.tipo), size: 32),
                    title: Text('${v.placa} · ${v.titulo}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${v.tipo}${v.color != null ? ' · ${v.color}' : ''}'),
                    onTap: () => _abrirForm(v),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        if (!await confirmar(context, 'Eliminar', '¿Eliminar el vehículo ${v.placa}?')) return;
                        try {
                          await Repo.eliminarVehiculo(v.id);
                          _recargar();
                        } catch (e) {
                          if (context.mounted) snack(context, e.toString(), error: true);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => _abrirForm(), child: const Icon(Icons.add)),
    );
  }
}

class VehiculoForm extends StatefulWidget {
  final Vehiculo? vehiculo;
  const VehiculoForm({super.key, this.vehiculo});
  @override
  State<VehiculoForm> createState() => _VehiculoFormState();
}

class _VehiculoFormState extends State<VehiculoForm> {
  final _form = GlobalKey<FormState>();
  late final _placa = TextEditingController(text: widget.vehiculo?.placa);
  late final _marca = TextEditingController(text: widget.vehiculo?.marca);
  late final _modelo = TextEditingController(text: widget.vehiculo?.modelo);
  late final _color = TextEditingController(text: widget.vehiculo?.color);
  late String _tipo = widget.vehiculo?.tipo ?? 'Auto';
  bool _guardando = false;

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    final d = {
      'placa': _placa.text.trim().toUpperCase(),
      'marca': _marca.text.trim(),
      'modelo': _modelo.text.trim(),
      'tipo': _tipo,
      'color': _color.text.trim(),
    };
    try {
      if (widget.vehiculo == null) {
        await Repo.crearVehiculo(d);
      } else {
        await Repo.actualizarVehiculo(widget.vehiculo!.id, d);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _t(TextEditingController c, String l, {bool req = false, TextCapitalization cap = TextCapitalization.words}) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          controller: c,
          textCapitalization: cap,
          decoration: InputDecoration(labelText: l),
          validator: req ? (v) => (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null : null,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.vehiculo == null ? 'Nuevo vehículo' : 'Editar vehículo')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          _t(_placa, 'Placa', req: true, cap: TextCapitalization.characters),
          _t(_marca, 'Marca', req: true),
          _t(_modelo, 'Modelo'),
          DropdownButtonFormField<String>(
            value: _tipo,
            decoration: const InputDecoration(labelText: 'Tipo'),
            items: const ['Auto', 'Camioneta', 'Vagoneta', 'Moto', 'Camión'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => _tipo = v!),
          ),
          const SizedBox(height: 14),
          _t(_color, 'Color'),
          ElevatedButton(onPressed: _guardando ? null : _guardar, child: Text(_guardando ? 'Guardando…' : 'Guardar')),
        ]),
      ),
    );
  }
}
