import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> mostrarPanelCuenta(BuildContext context) async {
  final auth = Supabase.instance.client.auth;
  final usuario = auth.currentUser;
  if (usuario == null) return;

  final salir = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.account_circle_outlined),
      title: const Text('Cuenta'),
      content: usuario.email == null
          ? null
          : SelectableText(usuario.email!, textAlign: TextAlign.center),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Volver'),
        ),
        OutlinedButton.icon(
          onPressed: () => Navigator.pop(dialogContext, true),
          icon: const Icon(Icons.logout),
          label: const Text('Cerrar sesión'),
        ),
      ],
    ),
  );

  if (salir != true || !context.mounted || auth.currentUser?.id != usuario.id) {
    return;
  }

  try {
    await auth.signOut();
  } on AuthException {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No se pudo cerrar la sesión. Inténtalo de nuevo.'),
      ),
    );
  }
}
