/// Compromiso de la agenda (algo que se da en una fecha y hora fijas).
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
