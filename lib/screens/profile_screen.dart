import 'package:flutter/material.dart';
import '../services/gemini_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _apiKeyCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _apiKeyVisible = false;
  bool _isSaving = false;
  bool _apiKeySaved = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final key = await GeminiService.getApiKey();
    setState(() {
      _apiKeyCtrl.text = key;
      _apiKeySaved = key.isNotEmpty;
    });
  }

  Future<void> _saveApiKey() async {
    setState(() => _isSaving = true);
    await GeminiService.saveApiKey(_apiKeyCtrl.text.trim());
    setState(() {
      _isSaving = false;
      _apiKeySaved = _apiKeyCtrl.text.trim().isNotEmpty;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ API key guardada correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        title: const Text('Perfil', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Avatar
          Center(
            child: CircleAvatar(
              radius: 48,
              backgroundColor: const Color(0xFF1A237E),
              child: const Icon(Icons.person, size: 52, color: Colors.white),
            ),
          ),
          const SizedBox(height: 24),

          // Nombre
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Tu nombre',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),

          // API Key section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.key, color: Color(0xFF1A237E)),
                    const SizedBox(width: 8),
                    const Text('API Key de Gemini',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const Spacer(),
                    if (_apiKeySaved)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('Activa', style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Necesitas una API key gratuita de Google AI Studio para usar el chat con IA.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _apiKeyCtrl,
                  obscureText: !_apiKeyVisible,
                  decoration: InputDecoration(
                    hintText: 'AIza...',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_apiKeyVisible ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _apiKeyVisible = !_apiKeyVisible),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Obtener API key'),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Ve a: aistudio.google.com/app/apikey')),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _isSaving ? null : _saveApiKey,
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1A237E)),
                        child: _isSaving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Guardar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Info
          const ListTile(
            leading: Icon(Icons.info_outline, color: Color(0xFF1A237E)),
            title: Text('NEUROPLAN AI'),
            subtitle: Text('v1.0.0 — Fundado por Rodrigo Luis Villadiego Acevedo'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }
}
