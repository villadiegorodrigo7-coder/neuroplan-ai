import 'package:uuid/uuid.dart';

import 'coleccion_nube.dart';

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

class HistorialRuedaService {
  static final _coleccion = ColeccionNube<RegistroRueda>(
    tabla: 'historial_rueda',
    soloAnexos: true,
    claveLocal: 'historial_rueda',
    idDe: (registro) => registro.id,
    aJson: (registro) => registro.toJson(),
    deJson: RegistroRueda.fromJson,
    aFila: (registro, uid) => {...registro.toJson(), 'user_id': uid},
    deFila: RegistroRueda.fromJson,
  );

  static Future<List<RegistroRueda>> cargar() async {
    final registros = await _coleccion.cargar();
    return registros..sort((a, b) => b.fecha.compareTo(a.fecha));
  }

  static Future<void> registrarValoraciones({
    required Map<String, int> anteriores,
    required Map<String, int> nuevos,
    required String? cicloId,
  }) async {
    final fecha = DateTime.now();
    final registros = <RegistroRueda>[];
    for (final pilar in {...anteriores.keys, ...nuevos.keys}) {
      final anterior = anteriores[pilar];
      final actual = nuevos[pilar];
      final base = anterior ?? actual;
      if (base == null || base < 0 || base > 10) continue;
      registros.add(
        RegistroRueda(
          id: 'inicio:$pilar',
          pilar: pilar,
          fecha: fecha,
          tipo: 'inicio',
          valor: base,
        ),
      );
      if (anterior != null &&
          actual != null &&
          anterior != actual &&
          actual >= 0 &&
          actual <= 10) {
        registros.add(
          RegistroRueda(
            id: const Uuid().v4(),
            pilar: pilar,
            fecha: fecha,
            tipo: 'valoracion',
            valor: actual,
            cicloId: cicloId,
          ),
        );
      }
    }
    await _coleccion.anexar(registros);
  }

  static Future<void> registrarAvance({
    required String pilar,
    required String nota,
    required String? cicloId,
  }) {
    final texto = nota.trim();
    if (texto.isEmpty) return Future.value();
    return _coleccion.anexar([
      RegistroRueda(
        id: const Uuid().v4(),
        pilar: pilar,
        fecha: DateTime.now(),
        tipo: 'avance',
        nota: texto,
        cicloId: cicloId,
      ),
    ]);
  }
}
