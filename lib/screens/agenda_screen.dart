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
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
