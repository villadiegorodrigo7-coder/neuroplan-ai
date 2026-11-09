/// Compromiso de agenda con intervalo horario y recurrencia opcional.
class AgendaEvent {
  final String id;
  String title;
  DateTime date; // Inicio de la primera ocurrencia (compatibilidad con código existente).
  DateTime endDate;
  bool aviso;
  String frecuencia; // unica, diaria, semanal, personalizada
  List<int> diasSemana; // DateTime.monday=1 ... sunday=7
  /// Estado de cada ocurrencia recurrente, indexado por yyyy-MM-dd.
  Map<String, bool> cumplimientos;

  AgendaEvent({
    required this.id,
    required this.title,
    required this.date,
    DateTime? endDate,
    this.aviso = false,
    this.frecuencia = 'unica',
    List<int>? diasSemana,
    Map<String, bool>? cumplimientos,
  })  : endDate = endDate ?? date.add(const Duration(hours: 1)),
        diasSemana = diasSemana ?? <int>[],
        cumplimientos = cumplimientos ?? <String, bool>{};

  Duration get duracion => endDate.difference(date);

  String claveOcurrencia([DateTime? dia]) {
    final d = dia ?? date;
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  bool realizadaEn([DateTime? dia]) => cumplimientos[claveOcurrencia(dia)] ?? false;

  bool ocurreEl(DateTime dia) {
    final d = DateTime(dia.year, dia.month, dia.day);
    final inicio = DateTime(date.year, date.month, date.day);
    if (d.isBefore(inicio)) return false;
    switch (frecuencia) {
      case 'diaria':
        return true;
      case 'semanal':
        return d.weekday == date.weekday;
      case 'personalizada':
        return diasSemana.contains(d.weekday);
      default:
        return d == inicio;
    }
  }

  DateTime? inicioEn(DateTime dia) {
    if (!ocurreEl(dia)) return null;
    return DateTime(dia.year, dia.month, dia.day, date.hour, date.minute);
  }

  DateTime? finEn(DateTime dia) {
    final inicio = inicioEn(dia);
    return inicio?.add(duracion);
  }

  AgendaEvent? ocurrenciaEn(DateTime dia) {
    final inicio = inicioEn(dia);
    if (inicio == null) return null;
    return AgendaEvent(
      id: id,
      title: title,
      date: inicio,
      endDate: inicio.add(duracion),
      aviso: aviso,
      frecuencia: frecuencia,
      diasSemana: diasSemana,
      cumplimientos: cumplimientos,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'date': date.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'aviso': aviso,
        'frecuencia': frecuencia,
        'diasSemana': diasSemana,
        'cumplimientos': cumplimientos,
      };

  factory AgendaEvent.fromJson(Map<String, dynamic> json) {
    final inicio = DateTime.parse(json['date'] as String);
    return AgendaEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      date: inicio,
      endDate: json['endDate'] == null
          ? inicio.add(const Duration(hours: 1))
          : DateTime.parse(json['endDate'] as String),
      aviso: json['aviso'] == true,
      frecuencia: json['frecuencia'] as String? ?? 'unica',
      cumplimientos: (json['cumplimientos'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v == true)) ?? <String, bool>{},
      diasSemana: (json['diasSemana'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          <int>[],
    );
  }
}
