import 'dart:convert';
import 'productividad_data.dart';

export 'productividad_data.dart';

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

/// Evaluación cualitativa de un bloque completo de la agenda.

/// Hábito independiente de las tareas y compromisos de la agenda.

/// ================== ETAPA 4: HACER SEGUIMIENTO (30 días) ==================




/// ================== ETAPA 5: EVALUAR ==================


/// ================== CONTENEDOR PRINCIPAL ==================

/// Propuesta de la Rueda de la Vida construida desde el diagnóstico conversacional.

class CuadernilloData {
  DiagnosticoInicial diagnosticoInicial;
  RuedaVida ruedaVida;
  DiagnosticoConversacional? diagnosticoConversacional;
  ConsumoTiempo consumoTiempo;
  MatrizEisenhower matrizEisenhower;
  RutinaSemanal rutinaSemanal;
  Seguimiento30Dias seguimiento30Dias;
  EvaluacionFinal evaluacionFinal;
  List<EvaluacionBloque> evaluacionesBloques;
  List<HabitoSeguimiento> habitos;

  bool etapa1Completada;
  bool etapa2Completada;
  bool etapa3Completada;
  bool etapa4Completada;
  bool etapa5Completada;

  CuadernilloData({
    DiagnosticoInicial? diagnosticoInicial,
    RuedaVida? ruedaVida,
    this.diagnosticoConversacional,
    ConsumoTiempo? consumoTiempo,
    MatrizEisenhower? matrizEisenhower,
    RutinaSemanal? rutinaSemanal,
    Seguimiento30Dias? seguimiento30Dias,
    EvaluacionFinal? evaluacionFinal,
    List<EvaluacionBloque>? evaluacionesBloques,
    List<HabitoSeguimiento>? habitos,
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
        evaluacionFinal = evaluacionFinal ?? EvaluacionFinal(),
        evaluacionesBloques = evaluacionesBloques ?? [],
        habitos = habitos ?? [];

  Map<String, dynamic> toJson() => {
        'diagnosticoInicial': diagnosticoInicial.toJson(),
        'ruedaVida': ruedaVida.toJson(),
        if (diagnosticoConversacional != null) 'diagnosticoConversacional': diagnosticoConversacional!.toJson(),
        'consumoTiempo': consumoTiempo.toJson(),
        'matrizEisenhower': matrizEisenhower.toJson(),
        'rutinaSemanal': rutinaSemanal.toJson(),
        'seguimiento30Dias': seguimiento30Dias.toJson(),
        'evaluacionFinal': evaluacionFinal.toJson(),
        'evaluacionesBloques': evaluacionesBloques.map((e) => e.toJson()).toList(),
        'habitos': habitos.map((h) => h.toJson()).toList(),
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
      diagnosticoConversacional: json['diagnosticoConversacional'] != null
          ? DiagnosticoConversacional.fromJson(Map<String, dynamic>.from(json['diagnosticoConversacional']))
          : null,
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
      evaluacionesBloques: ((json['evaluacionesBloques'] as List?) ?? const [])
          .map((e) => EvaluacionBloque.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      habitos: ((json['habitos'] as List?) ?? const [])
          .map((h) => HabitoSeguimiento.fromJson(Map<String, dynamic>.from(h as Map)))
          .toList(),
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
