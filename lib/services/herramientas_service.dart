import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/productividad_data.dart';

/// Datos de las herramientas activas de NEUROPLAN.
/// Almacena las herramientas actuales de forma independiente.
class HerramientasData {
  MatrizEisenhower matriz;
  Seguimiento30Dias seguimiento;
  EvaluacionFinal evaluacionFinal;
  List<EvaluacionBloque> evaluacionesBloques;
  List<HabitoSeguimiento> habitos;
  List<CicloNeuroplan> ciclos;
  DiagnosticoConversacional? diagnostico;

  HerramientasData({
    MatrizEisenhower? matriz,
    Seguimiento30Dias? seguimiento,
    EvaluacionFinal? evaluacionFinal,
    List<EvaluacionBloque>? evaluacionesBloques,
    List<HabitoSeguimiento>? habitos,
    List<CicloNeuroplan>? ciclos,
    this.diagnostico,
  })  : matriz = matriz ?? MatrizEisenhower(),
        seguimiento = seguimiento ?? Seguimiento30Dias(),
        evaluacionFinal = evaluacionFinal ?? EvaluacionFinal(),
        evaluacionesBloques = evaluacionesBloques ?? [],
        habitos = habitos ?? [],
        ciclos = ciclos ?? [];

  MatrizEisenhower get matrizEisenhower => matriz;
  set matrizEisenhower(MatrizEisenhower value) => matriz = value;
  Seguimiento30Dias get seguimiento30Dias => seguimiento;
  set seguimiento30Dias(Seguimiento30Dias value) => seguimiento = value;
  DiagnosticoConversacional? get diagnosticoConversacional => diagnostico;
  set diagnosticoConversacional(DiagnosticoConversacional? value) => diagnostico = value;

  Map<String, dynamic> toJson() => {
        'version': 1,
        'matriz': matriz.toJson(),
        'seguimiento': seguimiento.toJson(),
        'evaluacionFinal': evaluacionFinal.toJson(),
        'evaluacionesBloques': evaluacionesBloques.map((e) => e.toJson()).toList(),
        'habitos': habitos.map((h) => h.toJson()).toList(),
        'ciclos': ciclos.map((c) => c.toJson()).toList(),
        if (diagnostico != null) 'diagnostico': diagnostico!.toJson(),
      };

  factory HerramientasData.fromJson(Map<String, dynamic> json) {
    return HerramientasData(
      matriz: json['matriz'] is Map
          ? MatrizEisenhower.fromJson(Map<String, dynamic>.from(json['matriz']))
          : MatrizEisenhower(),
      seguimiento: json['seguimiento'] is Map
          ? Seguimiento30Dias.fromJson(Map<String, dynamic>.from(json['seguimiento']))
          : Seguimiento30Dias(),
      evaluacionFinal: json['evaluacionFinal'] is Map
          ? EvaluacionFinal.fromJson(Map<String, dynamic>.from(json['evaluacionFinal']))
          : EvaluacionFinal(),
      evaluacionesBloques: ((json['evaluacionesBloques'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => EvaluacionBloque.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      habitos: ((json['habitos'] as List?) ?? const [])
          .whereType<Map>()
          .map((h) => HabitoSeguimiento.fromJson(Map<String, dynamic>.from(h)))
          .toList(),
      ciclos: ((json['ciclos'] as List?) ?? const [])
          .whereType<Map>()
          .map((c) => CicloNeuroplan.fromJson(Map<String, dynamic>.from(c)))
          .toList(),
      diagnostico: json['diagnostico'] is Map
          ? DiagnosticoConversacional.fromJson(
              Map<String, dynamic>.from(json['diagnostico']))
          : null,
    );
  }

  /// Convierte una sola vez la estructura antigua a herramientas independientes.
  factory HerramientasData.desdeDatosAnteriores(Map<String, dynamic> json) {
    // Conservamos las estructuras anteriores como antecedentes separados.
    // Nunca las convertimos automáticamente en puntuaciones propuestas o
    // confirmadas: Ágora debe contrastarlas con la situación actual.
    final antecedentes = <String, dynamic>{};
    if (json['ruedaVida'] is Map) {
      antecedentes['ruedaVida'] =
          Map<String, dynamic>.from(json['ruedaVida']);
    }
    if (json['diagnosticoInicial'] is Map) {
      antecedentes['diagnosticoInicial'] =
          Map<String, dynamic>.from(json['diagnosticoInicial']);
    }

    final diagnosticoActual = json['diagnosticoConversacional'] is Map
        ? DiagnosticoConversacional.fromJson(
            Map<String, dynamic>.from(json['diagnosticoConversacional']))
        : null;
    if (diagnosticoActual != null) {
      diagnosticoActual.antecedentesHistoricos.addAll(antecedentes);
    }

    return HerramientasData(
      matriz: json['matrizEisenhower'] is Map
          ? MatrizEisenhower.fromJson(Map<String, dynamic>.from(json['matrizEisenhower']))
          : MatrizEisenhower(),
      seguimiento: json['seguimiento30Dias'] is Map
          ? Seguimiento30Dias.fromJson(Map<String, dynamic>.from(json['seguimiento30Dias']))
          : Seguimiento30Dias(),
      evaluacionFinal: json['evaluacionFinal'] is Map
          ? EvaluacionFinal.fromJson(Map<String, dynamic>.from(json['evaluacionFinal']))
          : EvaluacionFinal(),
      evaluacionesBloques: ((json['evaluacionesBloques'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => EvaluacionBloque.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      habitos: ((json['habitos'] as List?) ?? const [])
          .whereType<Map>()
          .map((h) => HabitoSeguimiento.fromJson(Map<String, dynamic>.from(h)))
          .toList(),
      diagnostico: diagnosticoActual ??
          (antecedentes.isNotEmpty
              ? DiagnosticoConversacional(antecedentesHistoricos: antecedentes)
              : null),
    );
  }
}

/// Almacenamiento propio de las herramientas.
/// Durante la transición lee el registro antiguo de Supabase y lo convierte;
/// a partir de ahí guarda únicamente el esquema independiente.
class HerramientasService {
  static const String _localKey = 'neuroplan_herramientas_v1';
  // Las herramientas nuevas viven dentro del JSONB existente de cuadernillos.
  // Se conserva intacto el contenido legado (ruedaVida, diagnosticoInicial, etc.).
  static const String _claveHerramientas = 'neuroplanHerramientasV1';
  static const String _tablaAntigua = 'cuadernillos';
  static final ValueNotifier<int> cambios = ValueNotifier<int>(0);
  static Future<void> _cola = Future.value();

  static SupabaseClient get _db => Supabase.instance.client;
  static String? get _uid => _db.auth.currentUser?.id;
  static String _claveCuenta(String? uid) =>
      uid == null ? _localKey : '${_localKey}__$uid';

  /// Recupera el ciclo anterior cuando la migración guardó el seguimiento
  /// pero todavía no creó su entrada en la lista nueva de ciclos.
  /// Conserva la fecha original y no altera registros ni marca el ciclo cerrado.
  static bool _recuperarCicloDesdeSeguimiento(HerramientasData data) {
    if (data.ciclos.isNotEmpty) return false;

    final fecha = data.seguimiento.fechaInicio.trim();
    if (fecha.isEmpty || DateTime.tryParse(fecha) == null) return false;

    data.ciclos.add(CicloNeuroplan(
      id: 'ciclo_migrado_$fecha',
      fechaInicio: fecha,
      duracionDias: 30,
      conciertoFinalCompletado: false,
      estado: 'activo',
    ));
    return true;
  }

  /// Si la copia nueva perdió la fecha, busca únicamente esa fecha en
  /// las fuentes anteriores. Los registros actuales nunca se reemplazan.
  static Future<void> _restaurarFechaInicioLegada(
    HerramientasData data,
    SharedPreferences prefs,
  ) async {
    if (data.ciclos.isNotEmpty || data.seguimiento.fechaInicio.trim().isNotEmpty) {
      return;
    }

    final legadoLocal = _uid == null\n        ? prefs.getString('cuadernillo_neuroplan_data')\n        : null;
    if (legadoLocal != null && legadoLocal.isNotEmpty) {
      try {
        final anterior = HerramientasData.desdeDatosAnteriores(
          Map<String, dynamic>.from(jsonDecode(legadoLocal)),
        );
        final fecha = anterior.seguimiento.fechaInicio.trim();
        if (fecha.isNotEmpty && DateTime.tryParse(fecha) != null) {
          data.seguimiento.fechaInicio = fecha;
          return;
        }
      } catch (_) {}
    }

    if (_uid == null) return;
    try {
      final fila = await _db
          .from(_tablaAntigua)
          .select('datos')
          .eq('user_id', _uid!)
          .maybeSingle();
      if (fila == null || fila['datos'] is! Map) return;

      final datos = Map<String, dynamic>.from(fila['datos']);
      final guardadas = datos[_claveHerramientas];
      final anterior = guardadas is Map
          ? HerramientasData.fromJson(Map<String, dynamic>.from(guardadas))
          : HerramientasData.desdeDatosAnteriores(datos);
      final fecha = anterior.seguimiento.fechaInicio.trim();
      if (fecha.isNotEmpty && DateTime.tryParse(fecha) != null) {
        data.seguimiento.fechaInicio = fecha;
      }
    } catch (_) {
      // La copia actual permanece intacta si la fuente histórica no responde.
    }
  }

  static Future<HerramientasData> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final uidAlIniciar = _uid;
    final localJson = prefs.getString(_claveCuenta(uidAlIniciar));
    if (localJson != null && localJson.isNotEmpty) {
      try {
        final data = HerramientasData.fromJson(
            Map<String, dynamic>.from(jsonDecode(localJson)));
        await _restaurarFechaInicioLegada(data, prefs);
        final cicloRecuperado = _recuperarCicloDesdeSeguimiento(data);

        // Una copia nueva puede haberse creado antes de migrar el diagnóstico
        // que seguía guardado en el cuadernillo anterior. Recuperamos solo ese
        // diagnóstico para no reemplazar ni perder las demás herramientas.
        final diagnosticoActual = data.diagnosticoConversacional;
        final tieneDiagnosticoActual = diagnosticoActual != null &&
            (diagnosticoActual.valoresPropuestos.isNotEmpty ||
                diagnosticoActual.valoresConfirmados.isNotEmpty ||
                diagnosticoActual.confirmado ||
                diagnosticoActual.antecedentesHistoricos.isNotEmpty);

        if (!tieneDiagnosticoActual) {
          DiagnosticoConversacional? diagnosticoAnterior;

          final legadoLocal = uidAlIniciar == null\n              ? prefs.getString('cuadernillo_neuroplan_data')\n              : null;
          if (legadoLocal != null && legadoLocal.isNotEmpty) {
            try {
              final jsonAnterior =
                  Map<String, dynamic>.from(jsonDecode(legadoLocal));
              diagnosticoAnterior = HerramientasData
                  .desdeDatosAnteriores(jsonAnterior)
                  .diagnosticoConversacional;
            } catch (_) {}
          }

          // Si el navegador ya no conserva la copia local antigua, intenta
          // recuperar la misma información desde la tabla histórica.
          if (diagnosticoAnterior == null && _uid != null) {
            try {
              final anterior = await _db
                  .from(_tablaAntigua)
                  .select('datos')
                  .eq('user_id', _uid!)
                  .maybeSingle();
              if (anterior != null && anterior['datos'] is Map) {
                final datosAnteriores =
                    Map<String, dynamic>.from(anterior['datos']);
                final herramientasGuardadas =
                    datosAnteriores[_claveHerramientas];
                if (herramientasGuardadas is Map) {
                  diagnosticoAnterior = HerramientasData.fromJson(
                    Map<String, dynamic>.from(herramientasGuardadas),
                  ).diagnosticoConversacional;
                } else {
                  diagnosticoAnterior = HerramientasData
                      .desdeDatosAnteriores(datosAnteriores)
                      .diagnosticoConversacional;
                }
              }
            } catch (_) {
              // La copia actual permanece intacta si la tabla antigua no está disponible.
            }
          }

          final tieneDiagnosticoAnterior = diagnosticoAnterior != null &&
              (diagnosticoAnterior.valoresPropuestos.isNotEmpty ||
                  diagnosticoAnterior.valoresConfirmados.isNotEmpty ||
                  diagnosticoAnterior.confirmado ||
                diagnosticoAnterior.antecedentesHistoricos.isNotEmpty);
          if (tieneDiagnosticoAnterior) {
            data.diagnosticoConversacional = diagnosticoAnterior;
          }
        }
        if (cicloRecuperado ||
            (!tieneDiagnosticoActual &&
                data.diagnosticoConversacional != null)) {
          await guardar(data);
        }
        return data;
      } catch (_) {
        // Si el dato local está dañado, intentamos recuperar la nube.
      }
    }

    Map<String, dynamic>? remoto;
    final uid = _uid;
    if (uid != null) {
      // Las herramientas actuales se guardan en una clave propia dentro del
      // JSONB de cuadernillos, sin reemplazar los datos históricos existentes.
      try {
        final anterior = await _db
            .from(_tablaAntigua)
            .select('datos')
            .eq('user_id', uid)
            .maybeSingle();
        if (anterior != null && anterior['datos'] is Map) {
          final datosAnteriores =
              Map<String, dynamic>.from(anterior['datos']);
          final herramientasGuardadas =
              datosAnteriores[_claveHerramientas];
          remoto = herramientasGuardadas is Map
              ? Map<String, dynamic>.from(herramientasGuardadas)
              : datosAnteriores;
        }
      } catch (_) {
        // La copia local sigue siendo una fuente válida.
      }
    }

    Map<String, dynamic>? origen = remoto;
    // El legado sin propietario solo es utilizable sin una cuenta activa.
    // No se importa a una cuenta distinta por accidente.
    if (origen == null && uid == null) {
      final antiguo = prefs.getString('cuadernillo_neuroplan_data');
      if (antiguo != null && antiguo.isNotEmpty) {
        try {
          origen = Map<String, dynamic>.from(jsonDecode(antiguo));
        } catch (_) {}
      }
    }

    if (origen == null) return HerramientasData();

    final data = origen['version'] == 1
        ? HerramientasData.fromJson(origen)
        : HerramientasData.desdeDatosAnteriores(origen);
    _recuperarCicloDesdeSeguimiento(data);
    if (_uid != uidAlIniciar) return HerramientasData();
    await guardar(data);
    return data;
  }

  static Future<void> guardar(HerramientasData data) async {
    final json = data.toJson();
    final encoded = jsonEncode(json);
    final prefs = await SharedPreferences.getInstance();
    final uid = _uid;
    await prefs.setString(_claveCuenta(uid), encoded);
    cambios.value++;

    if (uid == null) return;

    final tarea = _cola.then((_) async {
      try {
        final fila = await _db
            .from(_tablaAntigua)
            .select('datos')
            .eq('user_id', uid)
            .maybeSingle();
        final datosExistentes = fila != null && fila['datos'] is Map
            ? Map<String, dynamic>.from(fila['datos'])
            : <String, dynamic>{};

        // Solo actualizamos nuestra clave; ruedaVida y diagnosticoInicial
        // históricos permanecen exactamente como estaban.
        datosExistentes[_claveHerramientas] = json;
        await _db.from(_tablaAntigua).upsert({
          'user_id': uid,
          'datos': datosExistentes,
          'actualizada_en': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (error) {
        debugPrint('HerramientasService: no se pudo sincronizar cuadernillos: $error');
        // La copia local permanece disponible; el próximo guardado reintenta.
      }
    });
    _cola = tarea;
    await tarea;
  }

  /// Devuelve el ciclo que está en curso. Los ciclos cerrados permanecen
  /// en la lista como historial.
  static CicloNeuroplan? cicloActivo(HerramientasData data) {
    for (final ciclo in data.ciclos.reversed) {
      if (ciclo.estado == 'activo') return ciclo;
    }
    return null;
  }

  /// Inicia un ciclo únicamente cuando la persona confirma la acción desde
  /// una experiencia explícita de Ágora. No deduce fechas desde el diario.
  static Future<CicloNeuroplan> iniciarCiclo({int duracionDias = 30}) async {
    if (duracionDias < 1) {
      throw ArgumentError.value(duracionDias, 'duracionDias', 'Debe ser mayor que cero.');
    }
    final data = await cargar();
    final existente = cicloActivo(data);
    if (existente != null) return existente;

    final ahora = DateTime.now();
    final fecha = ahora.year.toString().padLeft(4, '0') + '-' +
        ahora.month.toString().padLeft(2, '0') + '-' +
        ahora.day.toString().padLeft(2, '0');
    final ciclo = CicloNeuroplan(
      id: 'ciclo_' + ahora.microsecondsSinceEpoch.toString(),
      fechaInicio: fecha,
      duracionDias: duracionDias,
    );
    data.ciclos.add(ciclo);
    await guardar(data);
    return ciclo;
  }

  /// Registra el cierre humano del ciclo después del Concierto Final.
  static Future<void> cerrarCiclo(String cicloId) async {
    final data = await cargar();
    final indice = data.ciclos.indexWhere((c) => c.id == cicloId);
    if (indice < 0) throw StateError('No se encontró el ciclo solicitado.');
    final ciclo = data.ciclos[indice];
    if (!ciclo.periodoCompletado(DateTime.now())) {
      throw StateError('El período del ciclo todavía no ha terminado.');
    }
    ciclo.conciertoFinalCompletado = true;
    ciclo.estado = 'cerrado';
    await guardar(data);
  }

  static Future<bool> tieneDatosGuardados() async {
    final prefs = await SharedPreferences.getInstance();
    final local = prefs.getString(_claveCuenta(_uid));
    if (local != null && local.isNotEmpty) return true;
    final uid = _uid;
    if (uid == null) {
      final antiguo = prefs.getString('cuadernillo_neuroplan_data');
      return antiguo != null && antiguo.isNotEmpty;
    }
    try {
      final fila = await _db
          .from(_tablaAntigua)
          .select('datos')
          .eq('user_id', uid)
          .maybeSingle();
      return fila != null;
    } catch (_) {
      return false;
    }
  }

  static Future<void> borrarTodo() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = _uid;
    await prefs.remove(_claveCuenta(uid));
    cambios.value++;
    if (uid != null) {
      try {
        final fila = await _db
            .from(_tablaAntigua)
            .select('datos')
            .eq('user_id', uid)
            .maybeSingle();
        if (fila != null && fila['datos'] is Map) {
          final datosExistentes = Map<String, dynamic>.from(fila['datos']);
          datosExistentes.remove(_claveHerramientas);
          await _db.from(_tablaAntigua).update({
            'datos': datosExistentes,
            'actualizada_en': DateTime.now().toUtc().toIso8601String(),
          }).eq('user_id', uid);
        }
      } catch (error) {
        debugPrint('HerramientasService: no se pudo limpiar la copia propia: $error');
      }
    }
  }
}
