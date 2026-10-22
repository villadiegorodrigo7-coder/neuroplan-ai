import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart' show MainNavigation;
import 'screens/login_screen.dart';

/// Muestra el login o la app según haya sesión.
/// Supabase guarda la sesión solo; al reabrir la app sigue iniciada.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? auth.currentSession;
        if (session == null) return const LoginScreen();
        // Key por usuario: al cambiar de cuenta se reconstruyen las pantallas.
        return MainNavigation(key: ValueKey(session.user.id));
      },
    );
  }
}
