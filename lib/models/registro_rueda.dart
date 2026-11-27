class RegistroRueda {
  const RegistroRueda({
    required this.id,
    required this.pilar,
    required this.fecha,
    required this.tipo,
    this.valor,
    this.nota = '',
    this.cicloId,
  });

  final String id;
  final String pilar;
  final DateTime fecha;
  final String tipo;
  final int? valor;
  final String nota;
  final String? cicloId;

  Map<String, dynamic> toJson() => {
    'id': id,
    'pilar': pilar,
    'registrado_en': fecha.toUtc().toIso8601String(),
    'tipo': tipo,
    'valor': valor,
    'nota': nota,
    'ciclo_id': cicloId,
  };

  factory RegistroRueda.fromJson(Map<String, dynamic> json) => RegistroRueda(
    id: json['id'] as String,
    pilar: json['pilar'] as String,
    fecha: DateTime.parse(json['registrado_en'] as String),
    tipo: json['tipo'] as String,
    valor: json['valor'] as int?,
    nota: json['nota'] as String? ?? '',
    cicloId: json['ciclo_id'] as String?,
  );
}
