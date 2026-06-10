import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AgendaEvent {
  final String title;
  final DateTime dateTime;
  final String description;
  final Color color;

  AgendaEvent({
    required this.title,
    required this.dateTime,
    this.description = '',
    this.color = const Color(0xFF3949AB),
  });
}

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  final List<AgendaEvent> _events = [];
  DateTime _selectedDay = DateTime.now();

  List<AgendaEvent> get _todayEvents => _events
      .where((e) =>
          e.dateTime.year == _selectedDay.year &&
          e.dateTime.month == _selectedDay.month &&
          e.dateTime.day == _selectedDay.day)
      .toList()
    ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

  Future<void> _addEvent() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    TimeOfDay time = TimeOfDay.now();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Nuevo evento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Título', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Descripción', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: Text('Hora: ${time.format(ctx)}'),
                onTap: () async {
                  final picked = await showTimePicker(context: ctx, initialTime: time);
                  if (picked != null) setS(() => time = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) return;
                setState(() {
                  _events.add(AgendaEvent(
                    title: titleCtrl.text.trim(),
                    description: descCtrl.text.trim(),
                    dateTime: DateTime(
                      _selectedDay.year,
                      _selectedDay.month,
                      _selectedDay.day,
                      time.hour,
                      time.minute,
                    ),
                  ));
                });
                Navigator.pop(ctx);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        title: const Text('Agenda', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Selector de semana
          Container(
            color: const Color(0xFF1A237E),
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildWeekSelector(),
          ),
          // Eventos del día
          Expanded(
            child: _todayEvents.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_available, size: 72, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Sin eventos este día', style: TextStyle(fontSize: 18, color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _todayEvents.length,
                    itemBuilder: (ctx, i) => _buildEventCard(_todayEvents[i]),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addEvent,
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildWeekSelector() {
    final days = List.generate(7, (i) {
      final d = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1 - i));
      return d;
    });

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: days.map((day) {
        final isSelected = day.day == _selectedDay.day &&
            day.month == _selectedDay.month &&
            day.year == _selectedDay.year;
        final hasEvents = _events.any((e) =>
            e.dateTime.day == day.day &&
            e.dateTime.month == day.month &&
            e.dateTime.year == day.year);

        return GestureDetector(
          onTap: () => setState(() => _selectedDay = day),
          child: Container(
            width: 40,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  DateFormat('E', 'es').format(day).substring(0, 2).toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected ? const Color(0xFF1A237E) : Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${day.day}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? const Color(0xFF1A237E) : Colors.white,
                  ),
                ),
                if (hasEvents)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(top: 3),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF1A237E) : Colors.greenAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEventCard(AgendaEvent event) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          width: 4,
          height: 50,
          decoration: BoxDecoration(
            color: event.color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('HH:mm').format(event.dateTime),
                style: const TextStyle(color: Color(0xFF3949AB), fontWeight: FontWeight.w500)),
            if (event.description.isNotEmpty) Text(event.description),
          ],
        ),
      ),
    );
  }
}
