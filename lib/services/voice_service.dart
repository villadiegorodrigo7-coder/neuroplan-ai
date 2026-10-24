import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Voz de Ágora: hablar (texto a voz) y dictar (voz a texto).
///
/// Las dos cosas usan lo que ya trae el navegador o el teléfono. La calidad de
/// la voz depende de las voces instaladas en cada dispositivo.
class VoiceService {
  static final stt.SpeechToText _speech = stt.SpeechToText();
  static final FlutterTts _tts = FlutterTts();

  // ------------------------------------------------------------------
  // HABLAR
  // ------------------------------------------------------------------

  static bool _ttsReady = false;
  static int _intentosVoz = 0;

  /// Velocidad elegida: 1,05 veces la normal. En la web la normal es 1.0; en
  /// Android y iPhone la normal es 0.5, de modo que 1,05 equivale a 0.525.
  static double get _velocidad => kIsWeb ? 1.05 : 0.525;

  /// Tono elegido (1.0 es el normal).
  static const double _tono = 1.0;

  /// Voz elegida por Rodrigo con el probador de voces. Si el dispositivo no la
  /// tiene (por ejemplo, fuera de Chrome), se usa la mejor voz disponible.
  static const List<String> _vocesPreferidas = [
    'google español de estados unidos',
  ];

  /// Acentos de español, del que más queremos al que menos. El de España va al
  /// final a propósito: la persona que usa la app es latinoamericana.
  static const List<String> _acentos = [
    'es-US', 'es-CO', 'es-MX', 'es-419', 'es-AR', 'es-CL', 'es-PE', 'es-VE',
  ];

  /// Pistas en el nombre de una voz que suelen indicar mejor calidad.
  static const List<String> _pistasCalidad = [
    'natural', 'neural', 'online', 'premium', 'enhanced', 'wavenet', 'google',
  ];

  static String _normalizar(String s) => s.replaceAll('_', '-').toLowerCase();

  /// Busca en el dispositivo la voz en español que más probablemente suene
  /// cálida. Devuelve null si todavía no hay voces cargadas.
  static Future<Map<String, String>?> _elegirMejorVoz() async {
    final crudas = await _tts.getVoices;
    if (crudas is! List) return null;

    // 1) La voz elegida por nombre, si está en este dispositivo.
    for (final pref in _vocesPreferidas) {
      for (final v in crudas) {
        if (v is! Map) continue;
        final nombre = (v['name'] ?? '').toString();
        final locale = (v['locale'] ?? '').toString();
        if (nombre.isNotEmpty &&
            locale.isNotEmpty &&
            nombre.toLowerCase().contains(pref)) {
          return {'name': nombre, 'locale': locale};
        }
      }
    }

    // 2) Si no, la que mejor puntúe entre las voces en español.
    Map<String, String>? mejor;
    var mejorPuntaje = -1;

    for (final v in crudas) {
      if (v is! Map) continue;
      final nombre = (v['name'] ?? '').toString();
      final locale = (v['locale'] ?? '').toString();
      final loc = _normalizar(locale);
      if (nombre.isEmpty || !loc.startsWith('es')) continue;

      var puntaje = 10; // cualquier español
      final posicion = _acentos.indexWhere((a) => a.toLowerCase() == loc);
      if (posicion >= 0) puntaje += (_acentos.length - posicion) * 10;
      final n = nombre.toLowerCase();
      for (final pista in _pistasCalidad) {
        if (n.contains(pista)) {
          puntaje += 25;
          break;
        }
      }

      if (puntaje > mejorPuntaje) {
        mejorPuntaje = puntaje;
        mejor = {'name': nombre, 'locale': locale};
      }
    }
    return mejor;
  }

  static Future<void> _ensureTts() async {
    if (_ttsReady) return;
    try {
      await _tts.setSpeechRate(_velocidad);
      await _tts.setPitch(_tono);
      await _tts.setVolume(1.0);

      final voz = await _elegirMejorVoz();
      if (voz != null) {
        await _tts.setVoice(voz);
        await _tts.setLanguage(voz['locale']!);
        _ttsReady = true;
      } else {
        // En la web las voces pueden tardar en cargar: se reintenta en el
        // próximo mensaje y, tras tres intentos, se sigue con español genérico.
        await _tts.setLanguage('es-US');
        _intentosVoz++;
        if (_intentosVoz >= 3) _ttsReady = true;
      }
    } catch (e) {
      debugPrint('Voz: no se pudo preparar la síntesis: $e');
      _intentosVoz++;
      if (_intentosVoz >= 3) _ttsReady = true;
    }
  }

  static Future<void> speak(String text) async {
    final limpio = text.trim();
    if (limpio.isEmpty) return;
    await _ensureTts();
    await _tts.stop();
    await _tts.speak(limpio);
  }

  static Future<void> stopSpeaking() async {
    await _tts.stop();
  }

  // ------------------------------------------------------------------
  // DICTAR
  // ------------------------------------------------------------------

  static bool _speechReady = false;
  static void Function()? _alTerminar;
  static void Function(String mensaje)? _alFallar;

  static void _terminar() {
    final f = _alTerminar;
    _alTerminar = null;
    f?.call();
  }

  static Future<bool> initSpeech() async {
    if (_speechReady) return true;
    _speechReady = await _speech.initialize(
      onError: (error) {
        debugPrint('Error de voz: $error');
        _alFallar?.call(error.errorMsg);
        _terminar();
      },
      onStatus: (status) {
        debugPrint('Estado de voz: $status');
        if (status == 'done' || status == 'notListening') _terminar();
      },
    );
    return _speechReady;
  }

  static bool get isListening => _speech.isListening;

  /// Elige el español latino disponible; si no hay, usa el del sistema.
  static Future<String?> _elegirIdiomaDictado() async {
    try {
      final idiomas = await _speech.locales();
      for (final pref in ['es_CO', 'es_MX', 'es_US', 'es_419']) {
        for (final l in idiomas) {
          if (_normalizar(l.localeId) == _normalizar(pref)) return l.localeId;
        }
      }
      for (final l in idiomas) {
        if (_normalizar(l.localeId).startsWith('es')) return l.localeId;
      }
    } catch (e) {
      debugPrint('Voz: no se pudieron leer los idiomas: $e');
    }
    return null;
  }

  /// Empieza a escuchar. [onResult] se llama mientras la persona habla, con el
  /// texto hasta ese momento, y una última vez con [finalResult] verdadero.
  /// Devuelve false si no se pudo activar el micrófono.
  static Future<bool> startListening({
    required void Function(String text, bool finalResult) onResult,
    required void Function() onDone,
    void Function(String mensaje)? onError,
  }) async {
    _alTerminar = onDone;
    _alFallar = onError;

    final disponible = await initSpeech();
    if (!disponible) {
      onError?.call('no_disponible');
      _terminar();
      return false;
    }

    final idioma = await _elegirIdiomaDictado();
    await _speech.listen(
      localeId: idioma,
      onResult: (r) => onResult(r.recognizedWords, r.finalResult),
      listenFor: const Duration(minutes: 3),
      pauseFor: const Duration(seconds: 8),
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
      ),
    );
    return true;
  }

  static Future<void> stopListening() async {
    await _speech.stop();
  }
}
