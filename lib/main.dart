import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/cliente/cliente_home.dart';
import 'screens/lavador/lavador_home.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider()..restaurarSesion(),
      child: const LimpiecingoApp(),
    ),
  );
}

class LimpiecingoApp extends StatelessWidget {
  const LimpiecingoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Limpiecingo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const _Raiz(),
    );
  }
}

/// Decide qué pantalla mostrar según la sesión y el rol.
class _Raiz extends StatelessWidget {
  const _Raiz();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!auth.autenticado) return const LoginScreen();
    if (auth.user!.esLavador) return const LavadorHome();
    return const ClienteHome();
  }
}
