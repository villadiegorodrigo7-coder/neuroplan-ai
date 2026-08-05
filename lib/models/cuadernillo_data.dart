import 'dart:convert';

/// ================== ETAPA 1: DIAGNOSTICAR ==================

class DiagnosticoInicial {
  int energia;
  int estres;
  int claridadMental;
  int organizacion;
  int motivacion;
  int satisfaccionGeneral;
  String nota;

  DiagnosticoInicial({
    this.energia = 5,
    this.estres = 5,
    this.claridadMental = 5,
    this.organizacion = 5,
    this.motivacion = 5,
    this.satisfaccionGeneral = 5,
    this.nota = '',
  });

  Map<String, dynamic> toJson() => {
        'energia': energia,
        'estres': estres,
        'claridadMental': claridadMental,
        'organizacion': organizacion,
        'motivacion': motivacion,
        'satisfaccionGeneral': satisfaccionGeneral,
        'nota': nota,
      };

  factory DiagnosticoInicial.fromJson(Map<String, dynamic> json) {
    return DiagnosticoInicial(
      energia: json['energia'] ?? 5,
      estres: json['estres'] ?? 5,
      claridadMental: json['claridadMental'] ?? 5,
      organizacion: json['organizacion'] ?? 5,
      motivacion: json['motivacion'] ?? 5,
      satisfaccionGeneral: json['satisfaccionGeneral'] ?? 5,
      nota: json['nota'] ?? '',
    );
  }
}

class RuedaVida {
  int salud;
  int estudios;
  int trabajo;
  int finanzas;
  int familia;
  int amigos;
  int descanso;
  int crecimiento;

  RuedaVida({
    this.salud = 5,
    this.estudios = 5,
    this.trabajo = 5,
    this.finanzas = 5,
    this.familia = 5,
    this.amigos = 5,
    this.descanso = 5,
    this.crecimiento = 5,
  });

  Map<String, dynamic> toJson() => {
        'salud': salud,
        'estudios': estudios,
        'trabajo': trabajo,
        'finanzas': finanzas,
        'familia': familia,
        'amigos': amigos,
        'descanso': descanso,
        'crecimiento': crecimiento,
      };

  factory RuedaVida.fromJson(Map<String, dynamic> json) {
    return RuedaVida(
      salud: json['salud'] ?? 5,
      estudios: json['estudios'] ?? 5,
      trabajo: json['trabajo'] ?? 5,
      finanzas: json['finanzas'] ?? 5,
      familia: json['familia'] ?? 5,
      amigos: json['amigos'] ?? 5,
      descanso: json['descanso'] ?? 5,
      crecimiento: json['crecimiento'] ?? 5,
    );
  }
}

class ConsumoTiempo {
  String redesSociales;
  String distracciones;
  String obligaciones;
  String habitos;

  ConsumoTiempo({
    this.redesSociales = '',
    this.distracciones = '',
    this.obligaciones = '',
    this.habitos = '',
  });

  Map<String, dynamic> toJson() => {
        'redesSociales': redesSociales,
        'distracciones': distracciones,
        'obligaciones': obligaciones,
        'habitos': habitos,
      };

  factory ConsumoTiempo.fromJson(Map<String, dynamic> json) {
    return ConsumoTiempo(
      redesSociales: json['redesSociales'] ?? '',
      distracciones: json['distracciones'] ?? '',
      obligaciones: json['obligaciones'] ?? '',
      habitos: json['habitos'] ?? '',
    );
  }
}

/// ================== ETAPA 2: PRIORIZAR ==================
/// Matriz de Eisenhower: 4 cuadrantes de tareas.

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

/// ================== ETAPA 3: ORGANIZAR ==================
/// Rutina semanal: bloques de mañana/tarde/noche para cada día.

class DiaRutina {
  String dia;
  String manana;
  String tarde;
  String noche;

  DiaRutina({
    required this.dia,
    this.manana = '',
    this.tarde = '',
    this.noche = '',
  });

  Map<String, dynamic> toJson() => {
        'dia': dia,
        'manana': manana,
        'tarde': tarde,
        'noche': noche,
      };

  factory DiaRutina.fromJson(Map<String, dynamic> json) {
    return DiaRutina(
      dia: json['dia'] ?? '',
      manana: json['manana'] ?? '',
      tarde: json['tarde'] ?? '',
      noche: json['noche'] ?? '',
    );
  }
}

class RutinaSemanal {
  List<DiaRutina> dias;

  RutinaSemanal({List<DiaRutina>? dias})
      : dias = dias ??
            [
              'Lunes',
              'Martes',
              'Miércoles',
              'Jueves',
              'Viernes',
              'Sábado',
              'Domingo',
            ].map((d) => DiaRutina(dia: d)).toList();

  Map<String, dynamic> toJson() => {
        'dias': dias.map((d) => d.toJson()).toList(),
      };

  factory RutinaSemanal.fromJson(Map<String, dynamic> json) {
    final lista = json['dias'] as List<dynamic>?;
    if (lista == null || lista.isEmpty) {
      return RutinaSemanal();
    }
    return RutinaSemanal(
      dias: lista
          .map((d) => DiaRutina.fromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// ================== ETAPA 4: HACER SEGUIMIENTO (30 días) ==================

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

  Seguimiento30Dias({List<RegistroDiario>? registros})
      : registros =
            registros ?? List.generate(30, (i) => RegistroDiario(dia: i + 1));

  Map<String, dynamic> toJson() => {
        'registros': registros.map((r) => r.toJson()).toList(),
      };

  factory Seguimiento30Dias.fromJson(Map<String, dynamic> json) {
    final lista = json['registros'] as List<dynamic>?;
    if (lista == null || lista.isEmpty) {
      return Seguimiento30Dias();
    }
    return Seguimiento30Dias(
      registros: lista
          .map((r) => RegistroDiario.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// ================== ETAPA 5: EVALUAR ==================

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

/// ================== CONTENEDOR PRINCIPAL ==================

class CuadernilloData {
  DiagnosticoInicial diagnosticoInicial;
  RuedaVida ruedaVida;
  ConsumoTiempo consumoTiempo;
  MatrizEisenhower matrizEisenhower;
  RutinaSemanal rutinaSemanal;
  Seguimiento30Dias seguimiento30Dias;
  EvaluacionFinal evaluacionFinal;

  bool etapa1Completada;
  bool etapa2Completada;
  bool etapa3Completada;
  bool etapa4Completada;
  bool etapa5Completada;

  CuadernilloData({
    DiagnosticoInicial? diagnosticoInicial,
    RuedaVida? ruedaVida,
    ConsumoTiempo? consumoTiempo,
    MatrizEisenhower? matrizEisenhower,
    RutinaSemanal? rutinaSemanal,
    Seguimiento30Dias? seguimiento30Dias,
    EvaluacionFinal? evaluacionFinal,
    this.etapa1Completada = false,
    this.etapa2Completada = false,
    this.etapa3Completada = false,
    this.etapa4Completada = false,
    this.etapa5Completada = false,
  })  : diagnosticoInicial = diagnosticoInicial ?? DiagnosticoInicial(),
        ruedaVida = ruedaVida ?? RuedaVida(),
        consumoTiempo = consumoTiempo ?? ConsumoTiempo(),
        matrizEisenhower = matrizEisenhower ?? MatrizEisenhower(),
        rutinaSemanal = rutinaSemanal ?? RutinaSemanal(),
        seguimiento30Dias = seguimiento30Dias ?? Seguimiento30Dias(),
        evaluacionFinal = evaluacionFinal ?? EvaluacionFinal();

  Map<String, dynamic> toJson() => {
        'diagnosticoInicial': diagnosticoInicial.toJson(),
        'ruedaVida': ruedaVida.toJson(),
        'consumoTiempo': consumoTiempo.toJson(),
        'matrizEisenhower': matrizEisenhower.toJson(),
        'rutinaSemanal': rutinaSemanal.toJson(),
        'seguimiento30Dias': seguimiento30Dias.toJson(),
        'evaluacionFinal': evaluacionFinal.toJson(),
        'etapa1Completada': etapa1Completada,
        'etapa2Completada': etapa2Completada,
        'etapa3Completada': etapa3Completada,
        'etapa4Completada': etapa4Completada,
        'etapa5Completada': etapa5Completada,
      };

  factory CuadernilloData.fromJson(Map<String, dynamic> json) {
    return CuadernilloData(
      diagnosticoInicial: json['diagnosticoInicial'] != null
          ? DiagnosticoInicial.fromJson(json['diagnosticoInicial'])
          : null,
      ruedaVida:
          json['ruedaVida'] != null ? RuedaVida.fromJson(json['ruedaVida']) : null,
      consumoTiempo: json['consumoTiempo'] != null
          ? ConsumoTiempo.fromJson(json['consumoTiempo'])
          : null,
      matrizEisenhower: json['matrizEisenhower'] != null
          ? MatrizEisenhower.fromJson(json['matrizEisenhower'])
          : null,
      rutinaSemanal: json['rutinaSemanal'] != null
          ? RutinaSemanal.fromJson(json['rutinaSemanal'])
          : null,
      seguimiento30Dias: json['seguimiento30Dias'] != null
          ? Seguimiento30Dias.fromJson(json['seguimiento30Dias'])
          : null,
      evaluacionFinal: json['evaluacionFinal'] != null
          ? EvaluacionFinal.fromJson(json['evaluacionFinal'])
          : null,
      etapa1Completada: json['etapa1Completada'] ?? false,
      etapa2Completada: json['etapa2Completada'] ?? false,
      etapa3Completada: json['etapa3Completada'] ?? false,
      etapa4Completada: json['etapa4Completada'] ?? false,
      etapa5Completada: json['etapa5Completada'] ?? false,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory CuadernilloData.fromJsonString(String jsonString) {
    return CuadernilloData.fromJson(jsonDecode(jsonString));
  }
}
