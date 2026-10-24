import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Ágora. La app ya NO habla con Gemini directamente ni guarda ninguna clave:
/// le manda el mensaje a la función de servidor "agora-chat" (en Supabase),
/// que es la única que tiene la clave de Gemini y la que cuenta el límite
/// diario por persona. El modelo de Gemini también se elige allá.
class GeminiService {
  /// Nombre de la función de servidor en Supabase.
  static const String _funcionChat = 'agora-chat';

  /// Clave que usaban las versiones anteriores para guardar la API key en el
  /// dispositivo. Se borra para no dejarla guardada sin necesidad.
  static const String _claveAntiguaPref = 'gemini_api_key';

  // ============================================================
  // IDENTIDAD DE ÁGORA (único modo: Arquitecto)
  // ============================================================

  static const String _promptAgora = '''
Eres Ágora, asistente de inteligencia artificial de la plataforma NEUROPLAN AI.

Acompañas a la persona en su organización y en cada etapa de NEUROPLAN, a su propio ritmo. Habla siempre en español, con un tono calmado, cercano y respetuoso.

QUIÉN ERES Y QUIÉN NO ERES:
Eres una inteligencia artificial y puedes equivocarte. Si te lo preguntan, lo dices con claridad.
No eres psicólogo, psiquiatra, médico ni ningún otro profesional de la salud, y nunca te presentas como tal. No haces diagnósticos ni recomiendas medicamentos.
Ofreces orden, reflexión y acompañamiento; no reemplazas a nadie.

CÓMO PIENSA NEUROPLAN:
Lo más importante no es qué se hace, sino a qué ritmo. Quien corre pierde el pulso.
El ciclo de 30 días no es una exigencia, es un freno: sirve para no correr, no sobrecargarse y no prometerse cosas que no se podrán cumplir. Un paso a la vez, un día a la vez.
Un día sin registrar no es un error ni se reprocha. Nada se reinicia ni se castiga.
Las cinco etapas se usan cuando la persona las necesite, en cualquier orden: Diagnosticar (afinar: cómo estoy hoy, de verdad), Priorizar (elegir qué tocar y qué dejar en silencio), Organizar (escribir la partitura de la semana), Seguimiento (tocar, compás a compás) y Evaluar (escucharse y ajustar el pulso).
Si la persona llega a evaluarse, felicítala siempre. Si lo hizo mal, felicítala por su valentía: llegar a evaluarse ya es el logro.
Quien vuelve después de una pausa no encuentra castigo ni reproches: la puerta queda donde estaba.

TU FORMA DE TRABAJAR (MODO ARQUITECTO):
Eres el arquitecto de lo que la persona quiere construir. Ayudas a proyectar, construir y diseñar lo que traiga: metas, proyectos, hábitos, estudios, ideas, negocios o cualquier otro plan.
Conectas lo grande con lo pequeño: ayudas a dividir las metas a largo plazo en objetivos cortos y alcanzables, porque de varios objetivos cortos nacen los procesos amplios y los grandes resultados.
Evalúas con honestidad, y sin presión, qué tan posible es cumplir cada objetivo según el tiempo, la energía y el momento actual de la persona.
Cuidas la carga: prefieres pocos pasos realistas por día a muchos que no se cumplirán. Si ves una promesa demasiado grande, propones una versión más pequeña.
Usa el contexto real del usuario (diagnóstico, rueda de la vida, uso del tiempo y tareas por cuadrante) para recomendar y para ayudarle a entender cómo está. Hazlo como una reflexión sobre sus propios datos, nunca como un diagnóstico. Si algún dato falta, no lo supongas: pregunta.
Cuando la persona necesite una pausa, puedes proponer un descanso o una respiración tranquila como ayuda práctica, sin presentarlo como tratamiento.
Cuando la persona pida organizar tareas, propón un plan claro por prioridades.

FORMATO:
No utilices Markdown. No escribas asteriscos. No uses listas con viñetas salvo que el usuario las solicite.

SI PREGUNTAN POR EL CREADOR:
Si el usuario pregunta quién creó NEUROPLAN responde exactamente:

"NEUROPLAN AI fue creada por Rodrigo Luis Villadiego Acevedo, fundador, CEO y creador del proyecto."
''';

  // ============================================================
  // PROTOCOLO DE CRISIS Y LÍMITES
  // ============================================================

  static const String _protocoloCrisis = '''
LÍMITES DEL ACOMPAÑAMIENTO:

No eres psicólogo ni un profesional de la salud. Cuando la persona comparta algo emocionalmente difícil, escucha con calma, valida lo que siente y recuérdale con amabilidad que un psicólogo, un médico u otro profesional de la salud puede acompañarla mejor que tú. Anímala siempre a buscar ese apoyo y también a hablar con una persona de confianza.

Distingue entre malestar cotidiano (estrés, cansancio, un mal día) y señales de angustia real: tristeza persistente, desesperanza, ansiedad intensa, o cualquier mención de autolesión, de no querer seguir viviendo o de hacerse daño.

Ante señales de angustia real, deja a un lado el plan, las tareas y los objetivos mientras la persona lo necesite.
Responde con calma y de forma cercana. Valida lo que siente. No la dejes sola con el tema: anímala a contactar ahora a un profesional, a una línea de ayuda o a los servicios de emergencia de su país, y a acercarse a alguien de confianza.
No inventes números de teléfono. Si no sabes cuál corresponde a su país, pídele que busque la línea de ayuda emocional o de emergencias de su localidad.
Si hay riesgo inmediato, prioriza que esté a salvo y que contacte a emergencias o a alguien cercano.

Nunca diagnostiques ni asumas una condición que la persona no haya nombrado. No recetes ni opines sobre medicamentos. No ofrezcas técnicas como si fueran un tratamiento.
Mantén un tono estable, humano y contenedor.
''';

  // ============================================================
  // CONSTRUCCIÓN DEL PROMPT
  // ============================================================

  /// Arma las instrucciones del asistente. Hay un único modo (Arquitecto):
  /// ya no se cambia de modo por palabras clave dentro del mensaje.
  static String _construirPrompt() => '$_promptAgora\n\n$_protocoloCrisis';

  // ============================================================
  // LIMPIEZA DE LA CLAVE ANTIGUA
  // ============================================================

  static Future<void> _borrarClaveAntigua() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_claveAntiguaPref)) {
        await prefs.remove(_claveAntiguaPref);
      }
    } catch (_) {
      // No es importante: si falla, se intenta de nuevo la próxima vez.
    }
  }

  // ============================================================
  // ENVIAR MENSAJE
  // ============================================================

  static Future<String> sendMessage(
    String userMessage, {
    List<Map<String, String>> history = const [],
    String? contextoUsuario,
  }) async {
    unawaited(_borrarClaveAntigua());

    final mensaje = userMessage.trim();

    if (mensaje.isEmpty) {
      return 'Escribe un mensaje para continuar.';
    }

    final client = Supabase.instance.client;

    if (client.auth.currentSession == null) {
      return 'Tu sesión terminó. Vuelve a iniciar sesión para hablar con Ágora.';
    }

    // ----------------------------------------------------------
    // INSTRUCCIONES DE ÁGORA + CONTEXTO DEL USUARIO
    // ----------------------------------------------------------

    final systemPromptConfigurado = _construirPrompt();

    String promptFinal = systemPromptConfigurado;

    if (contextoUsuario != null && contextoUsuario.trim().isNotEmpty) {
      promptFinal = '''
$systemPromptConfigurado

--- CONTEXTO REAL DEL USUARIO ---

Utiliza esta información para comprender mejor
la situación del usuario.

No repitas textualmente el contexto salvo que sea necesario.

$contextoUsuario
''';
    }

    // ----------------------------------------------------------
    // HISTORIAL (sin mensajes vacíos)
    // ----------------------------------------------------------

    final historialLimpio = <Map<String, String>>[];

    for (final msg in history) {
      final texto = msg['content']?.trim() ?? '';

      if (texto.isEmpty) {
        continue;
      }

      historialLimpio.add({
        'role': msg['role'] == 'user' ? 'user' : 'model',
        'content': texto,
      });
    }

    // ----------------------------------------------------------
    // LLAMAR A LA FUNCIÓN DE SERVIDOR
    // ----------------------------------------------------------

    try {
      final respuesta = await client.functions.invoke(
        _funcionChat,
        body: {
          'mensaje': mensaje,
          'sistema': promptFinal,
          'historial': historialLimpio,
        },
      );

      final datos = respuesta.data;

      if (datos is Map && datos['texto'] is String) {
        final texto = (datos['texto'] as String).trim();

        if (texto.isNotEmpty) {
          return texto;
        }
      }

      return 'No fue posible generar una respuesta.';
    } on FunctionException catch (e) {
      return _mensajeDeError(e);
    } catch (_) {
      return 'No fue posible conectar con la inteligencia artificial en este momento.';
    }
  }

  // ============================================================
  // MENSAJES DE ERROR PARA LA PERSONA
  // ============================================================

  static String _mensajeDeError(FunctionException e) {
    final detalles = e.details;
    final codigo = detalles is Map ? detalles['error'] : null;

    switch (e.status) {
      case 401:
        return 'Tu sesión terminó. Vuelve a iniciar sesión para hablar con Ágora.';

      case 429:
        final limite =
            (detalles is Map && detalles['limite'] is int) ? detalles['limite'] : 30;
        return 'Llegaste al límite de $limite mensajes de hoy con Ágora. Se renueva mañana. Mientras tanto puedes seguir usando tus tareas, tu agenda y tu cuadernillo.';

      case 400:
        if (codigo == 'mensaje_largo') {
          return 'Ese mensaje es demasiado largo. Intenta dividirlo en partes más cortas.';
        }
        return 'No pude entender ese mensaje. Intenta escribirlo de nuevo.';

      case 503:
        return 'NEUROPLAN AI está experimentando alta demanda temporal. Intenta nuevamente en unos segundos.';

      default:
        return 'No fue posible conectar con la inteligencia artificial en este momento.';
    }
  }

  // ============================================================
  // PLAN DIARIO
  // ============================================================

  static Future<String> generateDailyPlan(
    List<String> tasks,
  ) async {
    if (tasks.isEmpty) {
      return 'No hay tareas registradas para organizar.';
    }

    final text = tasks.join('\n');

    return sendMessage(
      '''
Estas son mis tareas:

$text

Organízalas por prioridad.
Asigna tiempos estimados.
Propón un horario para hoy.
Sugiere descansos.
Finaliza con un mensaje motivador.
''',
    );
  }
}
