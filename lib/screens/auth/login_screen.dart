import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/fondo.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _ver = false, _cargando = false;

  Future<void> _entrar() async {
    if (!_form.currentState!.validate()) return;
    HapticFeedback.lightImpact();
    setState(() => _cargando = true);
    try {
      await context.read<AuthProvider>().login(_email.text.trim(), _pass.text);
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(fit: StackFit.expand, children: [
        Image.asset('assets/images/login_bg.jpg', fit: BoxFit.cover, cacheWidth: 540, filterQuality: FilterQuality.low),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(.35), const Color(0xFF0B5E75).withOpacity(.92)],
            ),
          ),
        ),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                Animado(child: Image.asset('assets/images/logo.png', height: 130, cacheWidth: 400)),
                const SizedBox(height: 8),
                const Animado(
                  delayMs: 150,
                  child: Text('Tu auto limpio, donde estés', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                ),
                const SizedBox(height: 24),
                Animado(
                  delayMs: 300,
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.94),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 6))],
                    ),
                    child: Form(
                      key: _form,
                      child: Column(children: [
                        const Text('Iniciar sesión', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'Correo electrónico', prefixIcon: Icon(Icons.email_outlined)),
                          validator: (v) => (v == null || !v.contains('@')) ? 'Ingresa un correo válido' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _pass,
                          obscureText: !_ver,
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(icon: Icon(_ver ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _ver = !_ver)),
                          ),
                          validator: (v) => (v == null || v.isEmpty) ? 'Ingresa tu contraseña' : null,
                          onFieldSubmitted: (_) => _entrar(),
                        ),
                        const SizedBox(height: 22),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: ElevatedButton(
                            key: ValueKey(_cargando),
                            onPressed: _cargando ? null : _entrar,
                            child: _cargando
                                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                                : const Text('Entrar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Animado(
                  delayMs: 450,
                  child: TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                    child: const Text('¿No tienes cuenta? Regístrate', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
