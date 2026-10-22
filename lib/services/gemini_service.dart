import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GeminiService {
  static const String _apiKeyPref = 'gemini_api_key';

  // ============================================================
  // MODELO ACTUAL
  // ============================================================

  static const String _geminiModel = 'gemini-3.6-flash';

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
  // API KEY
  // ============================================================

  static Future<String> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(_apiKeyPref) ?? '';
  }

  static Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _apiKeyPref,
      key.trim(),
    );
  }

  // ============================================================
  // CONSTRUCCIÓN DEL PROMPT
  // ============================================================

  /// Arma las instrucciones del asistente. Hay un único modo (Arquitecto):
  /// ya no se cambia de modo por palabras clave dentro del mensaje.
  static String _construirPrompt() => '$_promptAgora\n\n$_protocoloCrisis';

  // ============================================================
  // GENERACIÓN CON REINTENTOS
  // ============================================================

  static Future<GenerateContentResponse> _generateWithRetry(
    GenerativeModel model,
    List<Content> conversation,
  ) async {
    const maxAttempts = 3;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await model.generateContent(
          conversation,
        );
      } catch (e) {
        final error = e.toString().toLowerCase();

        final temporaryError =
            error.contains('503') ||
            error.contains('unavailable') ||
            error.contains('timeout') ||
            error.contains('deadline') ||
            error.contains('temporarily');

        if (!temporaryError || attempt == maxAttempts) {
          rethrow;
        }

        await Future.delayed(
          Duration(
            seconds: attempt * 3,
          ),
        );
      }
    }

    throw Exception(
      'No fue posible obtener respuesta de Gemini.',
    );
  }

  // ============================================================
  // ENVIAR MENSAJE
  // ============================================================

  static Future<String> sendMessage(
    String userMessage, {
    List<Map<String, String>> history = const [],
    String? contextoUsuario,
  }) async {
    final apiKey = await getApiKey();

    if (apiKey.trim().isEmpty) {
      return 'Configura primero tu API Key de Gemini desde el perfil.';
    }

    final mensaje = userMessage.trim();

    if (mensaje.isEmpty) {
      return 'Escribe un mensaje para continuar.';
    }

    try {
      // ----------------------------------------------------------
      // DETERMINAR PROMPT
      // ----------------------------------------------------------

      final systemPromptConfigurado = _construirPrompt();

      // ----------------------------------------------------------
      // CONTEXTO DEL USUARIO
      // ----------------------------------------------------------

      String promptFinal =
          systemPromptConfigurado;

      if (
        contextoUsuario != null &&
        contextoUsuario.trim().isNotEmpty
      ) {
        promptFinal =
            '''
$systemPromptConfigurado

--- CONTEXTO REAL DEL USUARIO ---

Utiliza esta información para comprender mejor
la situación del usuario.

No repitas textualmente el contexto salvo que sea necesario.

$contextoUsuario
''';
      }

      // ----------------------------------------------------------
      // CREAR MODELO
      // ----------------------------------------------------------

      final model = GenerativeModel(
        model: _geminiModel,
        apiKey: apiKey.trim(),
        systemInstruction: Content.system(
          promptFinal,
        ),
      );

      // ----------------------------------------------------------
      // CREAR CONVERSACIÓN
      // ----------------------------------------------------------

      final List<Content> conversation = [];

      for (final msg in history) {
        final role =
            msg['role'] == 'user'
                ? 'user'
                : 'model';

        final contentText =
            msg['content']?.trim() ?? '';

        if (contentText.isEmpty) {
          continue;
        }

        conversation.add(
          Content(
            role,
            [
              TextPart(contentText),
            ],
          ),
        );
      }

      // ----------------------------------------------------------
      // MENSAJE ACTUAL
      // ----------------------------------------------------------

      conversation.add(
        Content(
          'user',
          [
            TextPart(mensaje),
          ],
        ),
      );

      // ----------------------------------------------------------
      // GENERAR RESPUESTA
      // ----------------------------------------------------------

      final response =
          await _generateWithRetry(
        model,
        conversation,
      );

      // ----------------------------------------------------------
      // VALIDAR RESPUESTA
      // ----------------------------------------------------------

      final responseText =
          response.text?.trim();

      if (
        responseText != null &&
        responseText.isNotEmpty
      ) {
        return responseText;
      }

      return 'No fue posible generar una respuesta.';
    } catch (e) {
      final error = e.toString().toLowerCase();

      // ----------------------------------------------------------
      // 503
      // ----------------------------------------------------------

      if (
        error.contains('503') ||
        error.contains('unavailable')
      ) {
        return 'NEUROPLAN AI está experimentando alta demanda temporal. Intenta nuevamente en unos segundos.';
      }

      // ----------------------------------------------------------
      // API KEY
      // ----------------------------------------------------------

      if (
        error.contains('api key') ||
        error.contains('apikey') ||
        error.contains('invalid api key')
      ) {
        return 'La API Key de Gemini no es válida o no está configurada correctamente.';
      }

      // ----------------------------------------------------------
      // AUTORIZACIÓN
      // ----------------------------------------------------------

      if (
        error.contains('401') ||
        error.contains('403') ||
        error.contains('permission')
      ) {
        return 'La API Key no tiene autorización para utilizar este servicio de Gemini.';
      }

      // ----------------------------------------------------------
      // CUOTA
      // ----------------------------------------------------------

      if (
        error.contains('429') ||
        error.contains('quota') ||
        error.contains('resource_exhausted')
      ) {
        return 'Se alcanzó temporalmente el límite de solicitudes de Gemini. Intenta nuevamente más tarde.';
      }

      // ----------------------------------------------------------
      // ERROR GENERAL
      // ----------------------------------------------------------

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
