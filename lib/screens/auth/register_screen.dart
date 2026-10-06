import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  String _tipo = 'Cliente';
  bool _cargando = false;

  final _c = <String, TextEditingController>{
    for (final k in [
      'name', 'email', 'password', 'password_confirmation', 'nombre', 'apellido', 'ci', 'telefono', 'direccion',
      'fecha_nacimiento', 'medio_transporte', 'licencia_numero', 'licencia_categoria', 'licencia_vencimiento',
      'banco', 'numero_cuenta', 'titular_cuenta', 'contacto_emergencia', 'telefono_emergencia',
    ])
      k: TextEditingController()
  };
  final Map<String, String> _fotos = {};

  bool get _lav => _tipo == 'Lavador';

  Widget _campo(String k, String label, {bool obligatorio = true, bool pass = false, TextInputType? tipo}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: _c[k],
          obscureText: pass,
          keyboardType: tipo,
          decoration: InputDecoration(labelText: label + (obligatorio ? '' : ' (opcional)')),
          validator: (v) {
            if (obligatorio && (v == null || v.trim().isEmpty)) return 'Campo obligatorio';
            if (k == 'email' && !(v ?? '').contains('@')) return 'Correo inválido';
            if (k == 'password' && (v ?? '').length < 8) return 'Mínimo 8 caracteres';
            if (k == 'password_confirmation' && v != _c['password']!.text) return 'No coincide';
            return null;
          },
        ),
      );

  Widget _fecha(String k, String label, {required DateTime first, required DateTime last, required DateTime initial}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: _c[k],
          readOnly: true,
          decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.calendar_today)),
          validator: (v) => (v == null || v.isEmpty) ? 'Campo obligatorio' : null,
          onTap: () async {
            final d = await showDatePicker(context: context, firstDate: first, lastDate: last, initialDate: initial);
            if (d != null) _c[k]!.text = DateFormat('yyyy-MM-dd').format(d);
          },
        ),
      );

  Widget _foto(String k, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: OutlinedButton.icon(
          icon: Icon(_fotos.containsKey(k) ? Icons.check_circle : Icons.photo_camera, color: _fotos.containsKey(k) ? Colors.green : null),
          label: Text(label + (_fotos.containsKey(k) ? ' ✓' : '')),
          onPressed: () async {
            final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1600);
            if (x != null) setState(() => _fotos[k] = x.path);
          },
        ),
      );

  Future<void> _enviar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      final campos = <String, dynamic>{'tipo_registro': _tipo};
      for (final e in _c.entries) {
        if (e.value.text.trim().isEmpty) continue;
        if (!_lav && const ['fecha_nacimiento', 'medio_transporte', 'licencia_numero', 'licencia_categoria', 'licencia_vencimiento', 'banco', 'numero_cuenta', 'titular_cuenta', 'contacto_emergencia', 'telefono_emergencia'].contains(e.key)) continue;
        campos[e.key] = e.value.text.trim();
      }
      final msg = await context.read<AuthProvider>().registrar(campos, archivos: _lav ? _fotos : {});
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
      snack(context, msg);
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Cliente', label: Text('Soy cliente'), icon: Icon(Icons.person)),
              ButtonSegment(value: 'Lavador', label: Text('Soy lavador'), icon: Icon(Icons.cleaning_services)),
            ],
            selected: {_tipo},
            onSelectionChanged: (s) => setState(() => _tipo = s.first),
          ),
          const SizedBox(height: 18),
          _campo('name', 'Nombre de usuario'),
          _campo('email', 'Correo electrónico', tipo: TextInputType.emailAddress),
          _campo('password', 'Contraseña', pass: true),
          _campo('password_confirmation', 'Confirmar contraseña', pass: true),
          _campo('nombre', 'Nombres'),
          _campo('apellido', 'Apellidos'),
          _campo('ci', 'Cédula de identidad'),
          _campo('telefono', 'Teléfono', tipo: TextInputType.phone),
          _campo('direccion', 'Dirección', obligatorio: false),
          if (_lav) ...[
            const Divider(height: 28),
            const Text('Datos del lavador', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _fecha('fecha_nacimiento', 'Fecha de nacimiento', first: DateTime(1940), last: DateTime.now().subtract(const Duration(days: 365 * 18)), initial: DateTime(1995)),
            _campo('medio_transporte', 'Medio de transporte (moto, auto, bici…)'),
            _campo('licencia_numero', 'N° de licencia'),
            _campo('licencia_categoria', 'Categoría de licencia'),
            _fecha('licencia_vencimiento', 'Vencimiento de licencia', first: DateTime.now().add(const Duration(days: 1)), last: DateTime.now().add(const Duration(days: 365 * 15)), initial: DateTime.now().add(const Duration(days: 365))),
            _campo('banco', 'Banco', obligatorio: false),
            _campo('numero_cuenta', 'N° de cuenta', obligatorio: false),
            _campo('titular_cuenta', 'Titular de la cuenta', obligatorio: false),
            _campo('contacto_emergencia', 'Contacto de emergencia'),
            _campo('telefono_emergencia', 'Teléfono de emergencia', tipo: TextInputType.phone),
            _foto('foto_perfil', 'Foto de perfil'),
            _foto('foto_licencia', 'Foto de licencia'),
            _foto('foto_ci_anverso', 'CI (anverso)'),
            _foto('foto_ci_reverso', 'CI (reverso)'),
            const Text('Tu cuenta quedará pendiente hasta que un administrador la apruebe.', style: TextStyle(color: Colors.orange)),
          ],
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _cargando ? null : _enviar,
            child: _cargando ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Registrarme'),
          ),
        ]),
      ),
    );
  }
}
