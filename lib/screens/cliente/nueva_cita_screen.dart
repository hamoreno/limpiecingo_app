import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../core/location.dart';
import '../../core/repository.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import '../../widgets/mapa.dart';

class NuevaCitaScreen extends StatefulWidget {
  const NuevaCitaScreen({super.key});
  @override
  State<NuevaCitaScreen> createState() => _NuevaCitaScreenState();
}

class _NuevaCitaScreenState extends State<NuevaCitaScreen> {
  final _form = GlobalKey<FormState>();
  late Future<List<dynamic>> _datos = Future.wait([Repo.servicios(), Repo.vehiculos()]);

  Servicio? _servicio;
  Vehiculo? _vehiculo;
  DateTime _fecha = DateTime.now();
  TimeOfDay _hora = TimeOfDay.now();
  LatLng? _punto;
  final _direccion = TextEditingController();
  final _obs = TextEditingController();
  bool _enviando = false, _ubicando = false;

  Future<void> _usarGps() async {
    setState(() => _ubicando = true);
    try {
      final p = await LocationHelper.actual();
      setState(() => _punto = LatLng(p.latitude, p.longitude));
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _ubicando = false);
    }
  }

  Future<void> _elegirEnMapa() async {
    final r = await Navigator.push<LatLng>(context, MaterialPageRoute(builder: (_) => SelectorUbicacion(inicial: _punto)));
    if (r != null) setState(() => _punto = r);
  }

  Future<void> _enviar() async {
    if (!_form.currentState!.validate()) return;
    if (_servicio == null || _vehiculo == null) {
      snack(context, 'Selecciona servicio y vehículo.', error: true);
      return;
    }
    if (_punto == null && _direccion.text.trim().isEmpty) {
      snack(context, 'Indica tu ubicación (GPS, mapa o dirección).', error: true);
      return;
    }
    setState(() => _enviando = true);
    try {
      await Repo.crearCita({
        'servicio_id': _servicio!.id,
        'vehiculo_id': _vehiculo!.id,
        'fecha': DateFormat('yyyy-MM-dd').format(_fecha),
        'hora': '${_hora.hour.toString().padLeft(2, '0')}:${_hora.minute.toString().padLeft(2, '0')}',
        if (_direccion.text.trim().isNotEmpty) 'direccion': _direccion.text.trim(),
        if (_punto != null) 'latitud': _punto!.latitude,
        if (_punto != null) 'longitud': _punto!.longitude,
        if (_obs.text.trim().isNotEmpty) 'observacion_cliente': _obs.text.trim(),
      });
      if (!mounted) return;
      snack(context, 'Tu solicitud de lavado fue registrada.');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitar lavado')),
      body: FutureBuilder<List<dynamic>>(
        future: _datos,
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) return const Cargando();
          if (s.hasError) return VistaError(s.error.toString(), () => setState(() => _datos = Future.wait([Repo.servicios(), Repo.vehiculos()])));
          final servicios = s.data![0] as List<Servicio>;
          final vehiculos = s.data![1] as List<Vehiculo>;
          if (vehiculos.isEmpty) return const Vacio('Primero registra un vehículo\nen la pestaña "Vehículos".', icono: Icons.directions_car);

          return Form(
            key: _form,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              DropdownButtonFormField<Servicio>(
                decoration: const InputDecoration(labelText: 'Servicio'),
                items: servicios.map((e) => DropdownMenuItem(value: e, child: Text('${e.nombre} · ${bs(e.precio)}'))).toList(),
                onChanged: (v) => setState(() => _servicio = v),
                validator: (v) => v == null ? 'Selecciona un servicio' : null,
              ),
              if (_servicio?.descripcion != null)
                Padding(padding: const EdgeInsets.only(top: 6), child: Text('${_servicio!.descripcion} (${_servicio!.duracionMinutos} min)', style: TextStyle(color: Colors.grey.shade700, fontSize: 13))),
              const SizedBox(height: 14),
              DropdownButtonFormField<Vehiculo>(
                decoration: const InputDecoration(labelText: 'Vehículo'),
                items: vehiculos.map((e) => DropdownMenuItem(value: e, child: Text('${e.placa} · ${e.titulo}'))).toList(),
                onChanged: (v) => setState(() => _vehiculo = v),
                validator: (v) => v == null ? 'Selecciona un vehículo' : null,
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(DateFormat('dd/MM/yyyy').format(_fecha)),
                    onPressed: () async {
                      final d = await showDatePicker(context: context, initialDate: _fecha, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
                      if (d != null) setState(() => _fecha = d);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.access_time),
                    label: Text(_hora.format(context)),
                    onPressed: () async {
                      final t = await showTimePicker(context: context, initialTime: _hora);
                      if (t != null) setState(() => _hora = t);
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 18),
              const Text('¿Dónde te encuentras?', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: OutlinedButton.icon(onPressed: _ubicando ? null : _usarGps, icon: const Icon(Icons.my_location), label: Text(_ubicando ? 'Buscando…' : 'Usar mi GPS'))),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton.icon(onPressed: _elegirEnMapa, icon: const Icon(Icons.map), label: const Text('Elegir en mapa'))),
              ]),
              if (_punto != null) ...[
                const SizedBox(height: 10),
                MapaVista(alto: 160, marcadores: [MarcadorMapa(_punto!, Icons.location_on, Colors.red)]),
              ],
              const SizedBox(height: 12),
              TextFormField(controller: _direccion, decoration: const InputDecoration(labelText: 'Dirección / referencia', prefixIcon: Icon(Icons.place))),
              const SizedBox(height: 12),
              TextFormField(controller: _obs, maxLines: 3, decoration: const InputDecoration(labelText: 'Observaciones (opcional)')),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _enviando ? null : _enviar, child: Text(_enviando ? 'Enviando…' : 'Solicitar lavado')),
            ]),
          );
        },
      ),
    );
  }
}
