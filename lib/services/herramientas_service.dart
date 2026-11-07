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
  DiagnosticoConversacional? diagnostico;

  HerramientasData({
    MatrizEisenhower? matriz,
    Seguimiento30Dias? seguimiento,
    EvaluacionFinal? evaluacionFinal,
    List<EvaluacionBloque>? evaluacionesBloques,
    List<HabitoSeguimiento>? habitos,
    this.diagnostico,
  })  : matriz = matriz ?? MatrizEisenhower(),
        seguimiento = seguimiento ?? Seguimiento30Dias(),
        evaluacionFinal = evaluacionFinal ?? EvaluacionFinal(),
        evaluacionesBloques = evaluacionesBloques ?? [],
        habitos = habitos ?? [];

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
      diagnostico: json['diagnostico'] is Map
          ? DiagnosticoConversacional.fromJson(
              Map<String, dynamic>.from(json['diagnostico']))
          : null,
    );
  }

  /// Convierte una sola vez la estructura antigua a herramientas independientes.
  factory HerramientasData.desdeDatosAnteriores(Map<String, dynamic> json) {
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
      diagnostico: json['diagnosticoConversacional'] is Map
          ? DiagnosticoConversacional.fromJson(
              Map<String, dynamic>.from(json['diagnosticoConversacional']))
          : null,
    );
  }
}

/// Almacenamiento propio de las herramientas.
/// Durante la transición lee el registro antiguo de Supabase y lo convierte;
/// a partir de ahí guarda únicamente el esquema independiente.
class HerramientasService {
  static const String _localKey = 'neuroplan_herramientas_v1';
  static const String _tablaTransicion = 'neuroplan_herramientas';
  static const String _tablaAntigua = 'cuadernillos';
  static final ValueNotifier<int> cambios = ValueNotifier<int>(0);
  static Future<void> _cola = Future.value();

  static SupabaseClient get _db => Supabase.instance.client;
  static String? get _uid => _db.auth.currentUser?.id;

  static Future<HerramientasData> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final localJson = prefs.getString(_localKey);
    if (localJson != null && localJson.isNotEmpty) {
      try {
        final data = HerramientasData.fromJson(
            Map<String, dynamic>.from(jsonDecode(localJson)));

        // Una copia nueva puede haberse creado antes de migrar el diagnóstico
        // que seguía guardado en el cuadernillo anterior. Recuperamos solo ese
        // diagnóstico para no reemplazar ni perder las demás herramientas.
        final diagnosticoActual = data.diagnosticoConversacional;
        final tieneDiagnosticoActual = diagnosticoActual != null &&
            (diagnosticoActual.valoresPropuestos.isNotEmpty ||
                diagnosticoActual.valoresConfirmados.isNotEmpty ||
                diagnosticoActual.confirmado);

        if (!tieneDiagnosticoActual) {
          DiagnosticoConversacional? diagnosticoAnterior;

          final legadoLocal = prefs.getString('cuadernillo_neuroplan_data');
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
                diagnosticoAnterior = HerramientasData.desdeDatosAnteriores(
                  Map<String, dynamic>.from(anterior['datos']),
                ).diagnosticoConversacional;
              }
            } catch (_) {
              // La copia actual permanece intacta si la tabla antigua no está disponible.
            }
          }

          final tieneDiagnosticoAnterior = diagnosticoAnterior != null &&
              (diagnosticoAnterior.valoresPropuestos.isNotEmpty ||
                  diagnosticoAnterior.valoresConfirmados.isNotEmpty ||
                  diagnosticoAnterior.confirmado);
          if (tieneDiagnosticoAnterior) {
            data.diagnosticoConversacional = diagnosticoAnterior;
            await guardar(data);
          }
        }
        return data;
      } catch (_) {
        // Si el dato local está dañado, intentamos recuperar la nube.
      }
    }

    Map<String, dynamic>? remoto;
    final uid = _uid;
    if (uid != null) {
      // Primero consulta el almacenamiento nuevo.
      try {
        final fila = await _db
            .from(_tablaTransicion)
            .select('datos')
            .eq('user_id', uid)
            .maybeSingle();
        if (fila != null && fila['datos'] is Map) {
          remoto = Map<String, dynamic>.from(fila['datos']);
        }
      } catch (_) {
        // La migración SQL puede no haberse aplicado todavía.
      }

      // Si no hay copia nueva, lee la tabla antigua solo para migrar.
      if (remoto == null) {
        try {
          final anterior = await _db
              .from(_tablaAntigua)
              .select('datos')
              .eq('user_id', uid)
              .maybeSingle();
          if (anterior != null && anterior['datos'] is Map) {
            remoto = Map<String, dynamic>.from(anterior['datos']);
          }
        } catch (_) {
          // La copia local sigue siendo una fuente válida.
        }
      }
    }

    Map<String, dynamic>? origen = remoto;
    if (origen == null) {
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
    await guardar(data);
    return data;
  }

  static Future<void> guardar(HerramientasData data) async {
    final json = data.toJson();
    final encoded = jsonEncode(json);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localKey, encoded);
    cambios.value++;

    final uid = _uid;
    if (uid == null) return;

    final tarea = _cola.then((_) async {
      try {
        await _db.from(_tablaTransicion).upsert({
          'user_id': uid,
          'datos': json,
          'actualizada_en': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (_) {
        // La copia local permanece disponible; el próximo guardado reintenta.
      }
    });
    _cola = tarea;
    await tarea;
  }

  static Future<bool> tieneDatosGuardados() async {
    final prefs = await SharedPreferences.getInstance();
    final local = prefs.getString(_localKey);
    if (local != null && local.isNotEmpty) return true;
    final uid = _uid;
    if (uid == null) {
      final antiguo = prefs.getString('cuadernillo_neuroplan_data');
      return antiguo != null && antiguo.isNotEmpty;
    }
    try {
      final fila = await _db
          .from(_tablaTransicion)
          .select('user_id')
          .eq('user_id', uid)
          .maybeSingle();
      if (fila != null) return true;
    } catch (_) {}
    try {
      final filaAntigua = await _db
          .from(_tablaAntigua)
          .select('user_id')
          .eq('user_id', uid)
          .maybeSingle();
      return filaAntigua != null;
    } catch (_) {
      return false;
    }
  }

  static Future<void> borrarTodo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localKey);
    cambios.value++;
    final uid = _uid;
    if (uid != null) {
      try {
        await _db.from(_tablaTransicion).delete().eq('user_id', uid);
      } catch (_) {}
    }
  }
}
