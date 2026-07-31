import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class AgendaEvent {
  final String id;
  String title;
  DateTime date;

  AgendaEvent({required this.id, required this.title, required this.date});

  Map<String, dynamic> toJson() =>
      {'id': id, 'title': title, 'date': date.toIso8601String()};

  factory AgendaEvent.fromJson(Map<String, dynamic> json) => AgendaEvent(
        id: json['id'],
        title: json['title'],
        date: DateTime.parse(json['date']),
      );
}

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  static const String _storageKey = 'agenda_events';
  final List<AgendaEvent> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      final List<dynamic> decoded = jsonDecode(raw);
      setState(() {
        _events.clear();
        _events.addAll(decoded.map((e) => AgendaEvent.fromJson(e)));
        _events.sort((a, b) => a.date.compareTo(b.date));
      });
    }
    setState(() => _loading = false);
  }

  Future<void> _saveEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_events.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  Future<void> _addEvent() async {
    final titleController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nuevo evento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
                trailing: const Icon(Icons.calendar_today, size: 20),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                  );
                  if (picked != null) {
                    setDialogState(() => selectedDate = picked);
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(selectedTime.format(context)),
                trailing: const Icon(Icons.access_time, size: 20),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: selectedTime,
                  );
                  if (picked != null) {
                    setDialogState(() => selectedTime = picked);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (result == true && titleController.text.trim().isNotEmpty) {
      final fullDate = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );
      setState(() {
        _events.add(AgendaEvent(
          id: const Uuid().v4(),
          title: titleController.text.trim(),
          date: fullDate,
        ));
        _events.sort((a, b) => a.date.compareTo(b.date));
      });
      _saveEvents();
    }
  }

  Future<void> _confirmDeleteEvent(AgendaEvent event) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar evento'),
        content: Text('¿Seguro que quieres eliminar "${event.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _events.removeWhere((e) => e.id == event.id));
      _saveEvents();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Agenda')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addEvent,
        backgroundColor: scheme.primary,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _events.isEmpty
              ? Center(
                  child: Text(
                    'No tienes eventos todavía.\nToca + para agregar uno',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _events.length,
                  itemBuilder: (context, index) {
                    final event = _events[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.event, color: scheme.primary, size: 20),
                        ),
                        title: Text(
                          event.title,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          DateFormat('dd/MM/yyyy · HH:mm').format(event.date),
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.5)),
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline,
                              color: Colors.white.withValues(alpha: 0.4),
                              size: 20),
                          onPressed: () => _confirmDeleteEvent(event),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
