import 'dart:convert';

/// Etapa 1 - Sección A: Diagnóstico Inicial
/// 6 escalas del 1 al 10 + una nota libre
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

/// Etapa 1 - Sección B: Rueda de la Vida
/// 8 áreas del 1 al 10
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

/// Etapa 1 - Sección C: Consumo de Tiempo
/// 4 campos de texto libre
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

/// Contenedor principal del Cuadernillo NEUROPLAN.
/// Por ahora solo incluye la Etapa 1 (Diagnosticar).
/// Las etapas 2-5 se irán agregando aquí más adelante.
class CuadernilloData {
  DiagnosticoInicial diagnosticoInicial;
  RuedaVida ruedaVida;
  ConsumoTiempo consumoTiempo;

  // Marca si la Etapa 1 ya fue completada por el usuario
  bool etapa1Completada;

  CuadernilloData({
    DiagnosticoInicial? diagnosticoInicial,
    RuedaVida? ruedaVida,
    ConsumoTiempo? consumoTiempo,
    this.etapa1Completada = false,
  })  : diagnosticoInicial = diagnosticoInicial ?? DiagnosticoInicial(),
        ruedaVida = ruedaVida ?? RuedaVida(),
        consumoTiempo = consumoTiempo ?? ConsumoTiempo();

  Map<String, dynamic> toJson() => {
        'diagnosticoInicial': diagnosticoInicial.toJson(),
        'ruedaVida': ruedaVida.toJson(),
        'consumoTiempo': consumoTiempo.toJson(),
        'etapa1Completada': etapa1Completada,
      };

  factory CuadernilloData.fromJson(Map<String, dynamic> json) {
    return CuadernilloData(
      diagnosticoInicial: json['diagnosticoInicial'] != null
          ? DiagnosticoInicial.fromJson(json['diagnosticoInicial'])
          : null,
      ruedaVida: json['ruedaVida'] != null
          ? RuedaVida.fromJson(json['ruedaVida'])
          : null,
      consumoTiempo: json['consumoTiempo'] != null
          ? ConsumoTiempo.fromJson(json['consumoTiempo'])
          : null,
      etapa1Completada: json['etapa1Completada'] ?? false,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory CuadernilloData.fromJsonString(String jsonString) {
    return CuadernilloData.fromJson(jsonDecode(jsonString));
  }
}
