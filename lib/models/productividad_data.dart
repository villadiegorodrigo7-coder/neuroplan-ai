/// Modelos independientes de las herramientas de NEUROPLAN.

class MatrizEisenhower {
  List<String> urgenteImportante;
  List<String> importanteNoUrgente;
  List<String> urgenteNoImportante;
  List<String> niUrgenteNiImportante;

  MatrizEisenhower({
    List<String>? urgenteImportante,
    List<String>? importanteNoUrgente,
    List<String>? urgenteNoImportante,
    List<String>? niUrgenteNiImportante,
  })  : urgenteImportante = urgenteImportante ?? [],
        importanteNoUrgente = importanteNoUrgente ?? [],
        urgenteNoImportante = urgenteNoImportante ?? [],
        niUrgenteNiImportante = niUrgenteNiImportante ?? [];

  Map<String, dynamic> toJson() => {
        'urgenteImportante': urgenteImportante,
        'importanteNoUrgente': importanteNoUrgente,
        'urgenteNoImportante': urgenteNoImportante,
        'niUrgenteNiImportante': niUrgenteNiImportante,
      };

  factory MatrizEisenhower.fromJson(Map<String, dynamic> json) {
    return MatrizEisenhower(
      urgenteImportante: List<String>.from(json['urgenteImportante'] ?? []),
      importanteNoUrgente:
          List<String>.from(json['importanteNoUrgente'] ?? []),
      urgenteNoImportante:
          List<String>.from(json['urgenteNoImportante'] ?? []),
      niUrgenteNiImportante:
          List<String>.from(json['niUrgenteNiImportante'] ?? []),
    );
  }
}

class EvaluacionBloque {
  String fecha;
  String bloque;
  String porQueDiaSalioAsi;
  String comoSalieronActividades;
  int satisfaccion;
  String porQueSatisfaccion;

  EvaluacionBloque({
    required this.fecha,
    required this.bloque,
    this.porQueDiaSalioAsi = '',
    this.comoSalieronActividades = '',
    this.satisfaccion = 0,
    this.porQueSatisfaccion = '',
  });

  Map<String, dynamic> toJson() => {
        'fecha': fecha,
        'bloque': bloque,
        'porQueDiaSalioAsi': porQueDiaSalioAsi,
        'comoSalieronActividades': comoSalieronActividades,
        'satisfaccion': satisfaccion,
        'porQueSatisfaccion': porQueSatisfaccion,
      };

  factory EvaluacionBloque.fromJson(Map<String, dynamic> json) =>
      EvaluacionBloque(
        fecha: (json['fecha'] ?? '').toString(),
        bloque: (json['bloque'] ?? '').toString(),
        porQueDiaSalioAsi: (json['porQueDiaSalioAsi'] ?? '').toString(),
        comoSalieronActividades: (json['comoSalieronActividades'] ?? '').toString(),
        satisfaccion: (json['satisfaccion'] as num?)?.toInt() ?? 0,
        porQueSatisfaccion: (json['porQueSatisfaccion'] ?? '').toString(),
      );
}

class HabitoSeguimiento {
  String id;
  String nombre;
  String tipo; // 'incorporar' o 'alejar'
  Map<String, bool> registros; // fecha local -> conducta observada

  HabitoSeguimiento({
    required this.id,
    required this.nombre,
    required this.tipo,
    Map<String, bool>? registros,
  }) : registros = registros ?? {};

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'tipo': tipo,
        'registros': registros,
      };

  factory HabitoSeguimiento.fromJson(Map<String, dynamic> json) =>
      HabitoSeguimiento(
        id: (json['id'] ?? '').toString(),
        nombre: (json['nombre'] ?? '').toString(),
        tipo: (json['tipo'] ?? 'incorporar').toString(),
        registros: Map<String, bool>.from(json['registros'] ?? {}),
      );
}

class TareaChecklist {
  String texto;
  bool completada;

  TareaChecklist({this.texto = '', this.completada = false});

  Map<String, dynamic> toJson() => {
        'texto': texto,
        'completada': completada,
      };

  factory TareaChecklist.fromJson(Map<String, dynamic> json) {
    return TareaChecklist(
      texto: json['texto'] ?? '',
      completada: json['completada'] ?? false,
    );
  }
}

class RegistroDiario {
  int dia;
  List<TareaChecklist> tareas;
  int estadoAnimo;
  String nota;
  int nivelCumplimiento;

  RegistroDiario({
    required this.dia,
    List<TareaChecklist>? tareas,
    this.estadoAnimo = 5,
    this.nota = '',
    this.nivelCumplimiento = 0,
  }) : tareas = tareas ?? [];

  Map<String, dynamic> toJson() => {
        'dia': dia,
        'tareas': tareas.map((t) => t.toJson()).toList(),
        'estadoAnimo': estadoAnimo,
        'nota': nota,
        'nivelCumplimiento': nivelCumplimiento,
      };

  factory RegistroDiario.fromJson(Map<String, dynamic> json) {
    final lista = json['tareas'] as List<dynamic>?;
    return RegistroDiario(
      dia: json['dia'] ?? 1,
      tareas: lista == null
          ? []
          : lista
              .map((t) => TareaChecklist.fromJson(t as Map<String, dynamic>))
              .toList(),
      estadoAnimo: json['estadoAnimo'] ?? 5,
      nota: json['nota'] ?? '',
      nivelCumplimiento: json['nivelCumplimiento'] ?? 0,
    );
  }
}

class Seguimiento30Dias {
  List<RegistroDiario> registros;

  /// Día en que empezó el ciclo, como "2026-10-24". Permite saber qué fecha
  /// corresponde a cada uno de los 30 días. Vacío = todavía no se definió.
  String fechaInicio;

  Seguimiento30Dias({List<RegistroDiario>? registros, this.fechaInicio = ''})
      : registros =
            registros ?? List.generate(30, (i) => RegistroDiario(dia: i + 1));

  Map<String, dynamic> toJson() => {
        'registros': registros.map((r) => r.toJson()).toList(),
        'fechaInicio': fechaInicio,
      };

  factory Seguimiento30Dias.fromJson(Map<String, dynamic> json) {
    final inicio = (json['fechaInicio'] ?? '').toString();
    final lista = json['registros'] as List<dynamic>?;
    if (lista == null || lista.isEmpty) {
      return Seguimiento30Dias(fechaInicio: inicio);
    }
    return Seguimiento30Dias(
      registros: lista
          .map((r) => RegistroDiario.fromJson(r as Map<String, dynamic>))
          .toList(),
      fechaInicio: inicio,
    );
  }
}

class EvaluacionFinal {
  String queFunciono;
  String queNoFunciono;
  String proximosPasos;

  EvaluacionFinal({
    this.queFunciono = '',
    this.queNoFunciono = '',
    this.proximosPasos = '',
  });

  Map<String, dynamic> toJson() => {
        'queFunciono': queFunciono,
        'queNoFunciono': queNoFunciono,
        'proximosPasos': proximosPasos,
      };

  factory EvaluacionFinal.fromJson(Map<String, dynamic> json) {
    return EvaluacionFinal(
      queFunciono: json['queFunciono'] ?? '',
      queNoFunciono: json['queNoFunciono'] ?? '',
      proximosPasos: json['proximosPasos'] ?? '',
    );
  }
}

class DiagnosticoConversacional {
  Map<String, int> valoresPropuestos;
  Map<String, int> valoresConfirmados;
  Map<String, String> fundamentos;
  String resumen;
  bool confirmado;
  /// Datos del esquema antiguo conservados como antecedentes, nunca como
  /// puntuaciones actuales ni como valores confirmados de la Rueda.
  Map<String, dynamic> antecedentesHistoricos;

  DiagnosticoConversacional({
    Map<String, int>? valoresPropuestos,
    Map<String, int>? valoresConfirmados,
    Map<String, String>? fundamentos,
    this.resumen = '',
    this.confirmado = false,
    Map<String, dynamic>? antecedentesHistoricos,
  })  : valoresPropuestos = valoresPropuestos ?? {},
        valoresConfirmados = valoresConfirmados ?? {},
        fundamentos = fundamentos ?? {},
        antecedentesHistoricos = antecedentesHistoricos ?? {};

  Map<String, dynamic> toJson() => {
        'valoresPropuestos': valoresPropuestos,
        'valoresConfirmados': valoresConfirmados,
        'fundamentos': fundamentos,
        'resumen': resumen,
        'confirmado': confirmado,
        if (antecedentesHistoricos.isNotEmpty)
          'antecedentesHistoricos': antecedentesHistoricos,
      };

  factory DiagnosticoConversacional.fromJson(Map<String, dynamic> json) =>
      DiagnosticoConversacional(
        valoresPropuestos: Map<String, int>.from(json['valoresPropuestos'] ?? {}),
        valoresConfirmados: Map<String, int>.from(json['valoresConfirmados'] ?? {}),
        fundamentos: Map<String, String>.from(json['fundamentos'] ?? {}),
        resumen: (json['resumen'] ?? '').toString(),
        confirmado: json['confirmado'] == true,
        antecedentesHistoricos: json['antecedentesHistoricos'] is Map
            ? Map<String, dynamic>.from(json['antecedentesHistoricos'])
            : {},
      );
}
