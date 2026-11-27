class ObjetivoRueda {
  ObjetivoRueda({
    required this.id,
    required this.nombre,
    required this.meta,
    required this.fechaMeta,
    List<AvanceObjetivo> avances = const [],
  }) : avances = List.unmodifiable(avances);

  final String id;
  final String nombre;
  final String meta;
  final String fechaMeta;
  final List<AvanceObjetivo> avances;

  int? get valor => avances.lastOrNull?.valor;

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'meta': meta,
    'fechaMeta': fechaMeta,
    'avances': avances.map((avance) => avance.toJson()).toList(),
  };

  factory ObjetivoRueda.fromJson(Map<String, dynamic> json) => ObjetivoRueda(
    id: json['id'] as String,
    nombre: json['nombre'] as String,
    meta: json['meta'] as String,
    fechaMeta: json['fechaMeta'] as String,
    avances: (json['avances'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(AvanceObjetivo.fromJson)
        .toList(),
  );
}

class AvanceObjetivo {
  const AvanceObjetivo({
    required this.fecha,
    required this.valor,
    required this.nota,
  });

  final DateTime fecha;
  final int valor;
  final String nota;

  Map<String, dynamic> toJson() => {
    'fecha': fecha.toUtc().toIso8601String(),
    'valor': valor,
    'nota': nota,
  };

  factory AvanceObjetivo.fromJson(Map<String, dynamic> json) => AvanceObjetivo(
    fecha: DateTime.parse(json['fecha'] as String),
    valor: json['valor'] as int,
    nota: json['nota'] as String? ?? '',
  );
}
