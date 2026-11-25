import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/agenda_event.dart';

class NuevoCompromisoDialog extends StatefulWidget {
  const NuevoCompromisoDialog({super.key, required this.fechaInicial});

  final DateTime fechaInicial;

  @override
  State<NuevoCompromisoDialog> createState() => _NuevoCompromisoDialogState();
}

class _NuevoCompromisoDialogState extends State<NuevoCompromisoDialog> {
  static const _dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  static const _duraciones = [15, 30, 45, 60, 90, 120, 180];
  static const _frecuencias = {
    'unica': 'Una sola vez',
    'diaria': 'Todos los días',
    'semanal': 'Cada semana',
    'personalizada': 'Días seleccionados',
  };

  final _titulo = TextEditingController();
  final _diasSemana = <int>{};
  late DateTime _fecha = widget.fechaInicial;
  TimeOfDay _hora = TimeOfDay.now();
  int _duracion = 60;
  String _frecuencia = 'unica';
  bool _aviso = true;

  @override
  void dispose() {
    _titulo.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (fecha != null && mounted) setState(() => _fecha = fecha);
  }

  Future<void> _elegirHora() async {
    final hora = await showTimePicker(context: context, initialTime: _hora);
    if (hora != null && mounted) setState(() => _hora = hora);
  }

  String _etiquetaDuracion(int minutos) {
    if (minutos < 60) return '$minutos minutos';
    final horas = minutos ~/ 60;
    final resto = minutos % 60;
    return resto == 0 ? '$horas h' : '$horas h $resto min';
  }

  void _guardar() {
    final inicio = DateTime(
      _fecha.year,
      _fecha.month,
      _fecha.day,
      _hora.hour,
      _hora.minute,
    );
    Navigator.pop(
      context,
      AgendaEvent(
        id: const Uuid().v4(),
        title: _titulo.text.trim(),
        date: inicio,
        endDate: inicio.add(Duration(minutes: _duracion)),
        aviso: _aviso,
        frecuencia: _frecuencia,
        diasSemana: _diasSemana.toList()..sort(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final personalizado = _frecuencia == 'personalizada';
    final puedeGuardar =
        _titulo.text.trim().isNotEmpty &&
        (!personalizado || _diasSemana.isNotEmpty);

    return AlertDialog(
      title: const Text('Nuevo compromiso'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titulo,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Actividad'),
                onChanged: (_) => setState(() {}),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Fecha de inicio'),
                subtitle: Text(DateFormat('dd/MM/yyyy').format(_fecha)),
                trailing: const Icon(Icons.calendar_today),
                onTap: _elegirFecha,
              ),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _elegirHora,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Hora de inicio',
                        ),
                        child: Text(_hora.format(context)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: _duracion,
                      decoration: const InputDecoration(labelText: 'Duración'),
                      items: [
                        for (final minutos in _duraciones)
                          DropdownMenuItem(
                            value: minutos,
                            child: Text(
                              _etiquetaDuracion(minutos),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (valor) =>
                          setState(() => _duracion = valor ?? 60),
                    ),
                  ),
                ],
              ),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _frecuencia,
                decoration: const InputDecoration(labelText: 'Se repite'),
                items: [
                  for (final frecuencia in _frecuencias.entries)
                    DropdownMenuItem(
                      value: frecuencia.key,
                      child: Text(
                        frecuencia.value,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (valor) =>
                    setState(() => _frecuencia = valor ?? 'unica'),
              ),
              if (personalizado)
                Wrap(
                  spacing: 3,
                  children: [
                    for (var dia = 1; dia <= _dias.length; dia++)
                      FilterChip(
                        label: Text(_dias[dia - 1]),
                        selected: _diasSemana.contains(dia),
                        onSelected: (elegido) => setState(() {
                          if (elegido) {
                            _diasSemana.add(dia);
                          } else {
                            _diasSemana.remove(dia);
                          }
                        }),
                      ),
                  ],
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Activar aviso'),
                value: _aviso,
                onChanged: (activo) => setState(() => _aviso = activo),
              ),
              const Text(
                'Los compromisos recurrentes siguen activos hasta que los elimines.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: puedeGuardar ? _guardar : null,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
