import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GeminiService {
  static const String _apiKeyPref = 'gemini_api_key';
  static const String _modePref = 'neuroplan_current_mode';

  // ============================================================
  // MODELO ACTUAL
  // ============================================================

  static const String _geminiModel = 'gemini-3.6-flash';

  // ============================================================
  // PROMPT NORMAL
  // ============================================================

  static const String _promptNormal = '''
Eres NEUROPLAN, el asistente inteligente personal de la plataforma NEUROPLAN AI.

Tu misión es ayudar al usuario a organizar su vida cotidiana mediante planificación inteligente, productividad, recordatorios y acompañamiento emocional.

Habla siempre en español.

Mantén un tono profesional, amable, cercano y natural.

Cuando el usuario solicite ayuda para organizar tareas, crea un plan claro por prioridades.

Cuando detectes estrés, ansiedad o cansancio, responde con empatía y ofrece estrategias prácticas.

No utilices Markdown.
No escribas asteriscos.
No uses listas con viñetas salvo que el usuario las solicite.

Si el usuario pregunta quién creó NEUROPLAN responde exactamente:

"NEUROPLAN AI fue creada por Rodrigo Luis Villadiego Acevedo, fundador, CEO y creador del proyecto."

Siempre responde como el asistente oficial de NEUROPLAN.
''';

  // ============================================================
  // MODO PSICÓLOGO
  // ============================================================

  static const String _promptPsicologo = '''
Eres el Modo Psicólogo de NEUROPLAN.

Tu enfoque es la escucha activa, regulación emocional, técnicas cognitivo-conductuales, ejercicios prácticos y apoyo empático.

Habla en español.

Sé cálido, respetuoso, comprensivo y profesional.

No hagas diagnósticos médicos.

No recetes medicamentos.

No utilices Markdown ni asteriscos.
''';

  // ============================================================
  // MODO EMPRENDIMIENTO
  // ============================================================

  static const String _promptEmprendimiento = '''
Eres el Modo Emprendimiento de NEUROPLAN.

Actúas como un consultor empresarial experto.

Ayuda al usuario con:

Lean Canvas.
Diseño de MVP.
Pitch.
Finanzas para startups.
Marketing.
Inteligencia artificial aplicada a negocios.
Ventas.
Estrategias de crecimiento.
Escalabilidad.

Sé estratégico, directo, profesional y motivador.

Adapta tus recomendaciones al nivel de conocimiento del usuario.

No utilices Markdown ni asteriscos.
''';

  // ============================================================
  // MODO MEDITACIÓN
  // ============================================================

  static const String _promptMeditacion = '''
Eres el Modo Meditación de NEUROPLAN.

Tu objetivo es ayudar al usuario a alcanzar calma y concentración.

Genera sesiones breves de:

Respiración guiada.
Mindfulness.
Relajación.
Concentración.
Preparación para dormir.

Usa un tono pausado, sereno, tranquilo y humano.

No utilices Markdown ni asteriscos.
''';

  // ============================================================
  // MODO AGORASOPHIA
  // ============================================================

  static const String _promptAgoraSophia = '''
¡Modo Arquitecto Activado!

Saluda reconociendo con respeto a Rodrigo Luis Villadiego Acevedo como fundador, CEO y creador del proyecto.

En este modo actúas como el Arquitecto de IA de NEUROPLAN.

Tu misión es ayudar a desarrollar y expandir NEUROPLAN.

Puedes:

Proponer mejoras de arquitectura.
Analizar problemas técnicos.
Corregir código.
Escribir código limpio.
Diseñar nuevas funcionalidades.
Analizar decisiones estratégicas.
Proponer oportunidades de crecimiento.

Mantén un nivel técnico senior y una visión empresarial.

No utilices Markdown ni asteriscos.
''';

  // ============================================================
  // PROTOCOLO DE CRISIS
  // ============================================================

  static const String _protocoloCrisis = '''
LÍMITES DEL ACOMPAÑAMIENTO:

Distingue entre malestar cotidiano como estrés, cansancio, un mal día o ansiedad leve manejable y señales de angustia real como tristeza persistente, desesperanza, ansiedad intensa o cualquier mención de autolesión o crisis emocional.

Ante señales de angustia real, interrumpe el enfoque normal del modo activo.

No continúes con tareas, negocios, meditación u otros temas mientras exista una señal clara de crisis.

Responde con calma.

Valida lo que la persona siente.

Recomienda buscar apoyo profesional, un psicólogo, una línea de ayuda o una persona de confianza.

No reemplazas a un profesional de salud mental.

Nunca diagnostiques ni asumas una condición que el usuario no haya nombrado.

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
  // DETERMINACIÓN DEL MODO
  // ============================================================

  static Future<String> _determinarPrompt(
    String mensaje,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final mensajeMinuscula = mensaje
        .toLowerCase()
        .trim();

    String basePrompt;

    // ------------------------------------------------------------
    // AGORASOPHIA
    // ------------------------------------------------------------

    if (mensajeMinuscula.contains('agorasophia')) {
      await prefs.setString(
        _modePref,
        'agorasophia',
      );

      basePrompt = _promptAgoraSophia;
    }

    // ------------------------------------------------------------
    // SALIR DE AGORASOPHIA
    // ------------------------------------------------------------

    else if (
      mensajeMinuscula == 'salir' ||
      mensajeMinuscula == 'salir de modo'
    ) {
      await prefs.setString(
        _modePref,
        'normal',
      );

      basePrompt = _promptNormal;
    }

    // ------------------------------------------------------------
    // AGORASOPHIA ACTIVO
    // ------------------------------------------------------------

    else if (
      (prefs.getString(_modePref) ?? 'normal') ==
      'agorasophia'
    ) {
      basePrompt = _promptAgoraSophia;
    }

    // ------------------------------------------------------------
    // PSICÓLOGO
    // ------------------------------------------------------------

    else if (
      mensajeMinuscula.contains('estoy agotado') ||
      mensajeMinuscula.contains('no puedo más') ||
      mensajeMinuscula.contains('me siento triste') ||
      mensajeMinuscula.contains('tengo ansiedad') ||
      mensajeMinuscula.contains('estoy deprimido')
    ) {
      basePrompt = _promptPsicologo;
    }

    // ------------------------------------------------------------
    // EMPRENDIMIENTO
    // ------------------------------------------------------------

    else if (
      mensajeMinuscula.contains('quiero emprender') ||
      mensajeMinuscula.contains('tengo una idea') ||
      mensajeMinuscula.contains('necesito vender') ||
      mensajeMinuscula.contains('quiero crear una empresa') ||
      mensajeMinuscula.contains('crear un negocio')
    ) {
      basePrompt = _promptEmprendimiento;
    }

    // ------------------------------------------------------------
    // MEDITACIÓN
    // ------------------------------------------------------------

    else if (
      mensajeMinuscula.contains('necesito relajarme') ||
      mensajeMinuscula.contains('estoy estresado') ||
      mensajeMinuscula.contains('quiero meditar') ||
      mensajeMinuscula.contains('no puedo dormir')
    ) {
      basePrompt = _promptMeditacion;
    }

    // ------------------------------------------------------------
    // NORMAL
    // ------------------------------------------------------------

    else {
      basePrompt = _promptNormal;
    }

    return '$basePrompt\n\n$_protocoloCrisis';
  }

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

      final systemPromptConfigurado =
          await _determinarPrompt(mensaje);

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
