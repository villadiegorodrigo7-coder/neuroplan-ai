/// Compromiso de la agenda (algo que se da en una fecha y hora fijas).
class AgendaEvent {
  final String id;
  String title;
  DateTime date;

  /// Si es verdadero, cuando llega la hora y la app está abierta se le
  /// recuerda a la persona.
  bool aviso;

  AgendaEvent({
    required this.id,
    required this.title,
    required this.date,
    this.aviso = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'date': date.toIso8601String(),
        'aviso': aviso,
      };

  factory AgendaEvent.fromJson(Map<String, dynamic> json) => AgendaEvent(
        id: json['id'],
        title: json['title'],
        date: DateTime.parse(json['date']),
        aviso: json['aviso'] == true,
      );
}
