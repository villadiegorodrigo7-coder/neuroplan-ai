import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [scheme.primary, scheme.primary.withValues(alpha: 0.4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.person, size: 44, color: Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              Supabase.instance.client.auth.currentUser?.email ?? '',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.76),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            // Al cerrar sesión, la puerta de acceso vuelve a la pantalla de
            // ingreso. Los datos de esta cuenta quedan guardados en la nube.
            onPressed: () => Supabase.instance.client.auth.signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}
