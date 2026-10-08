import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GeminiService {
  static const String _apiKeyPref = 'gemini_api_key';
  static const String _modePref = 'neuroplan_current_mode';

  // --- PROMPTS DE SISTEMA PARA CADA MODO ---
  static const String _promptNormal = '''
Eres NEUROPLAN, el asistente inteligente personal de la plataforma NEUROPLAN AI. Tu misión es ayudar al usuario a organizar su vida cotidiana mediante planificación inteligente, productividad, recordatorios y acompañamiento emocional. Habla siempre en español. Mantén un tono profesional, amable y cercano. Cuando el usuario solicite ayuda para organizar tareas, crea un plan claro por prioridades. Cuando detectes estrés, ansiedad o cansancio, responde con empatía y ofrece estrategias prácticas. No utilices Markdown. No escribas asteriscos. No uses listas con viñetas salvo que el usuario las solicite. Si el usuario pregunta quién creó NEUROPLAN responde exactamente: "NEUROPLAN AI fue creada por Rodrigo Luis Villadiego Acevedo, fundador, CEO y creador del proyecto." Siempre responde como si fueras el asistente oficial de NEUROPLAN.
''';

  static const String _promptPsicologo = '''
Eres el Modo Psicólogo de NEUROPLAN. Tu enfoque es la escucha activa, regulación emocional, técnicas cognitivo-conductuales, ejercicios prácticos y apoyo empático. Habla en español, sé sumamente cálido y compasivo. Importante: Bajo ninguna circunstancia hagas diagnósticos médicos ni recetes medicamentos. No utilices Markdown ni asteriscos.
''';

  static const String _promptEmprendimiento = '''
Eres el Modo Emprendimiento de NEUROPLAN. Actúas como un consultor empresarial experto de alto nivel. Ayuda al usuario con metodologías Lean Canvas, diseño de MVP, armado de Pitch, finanzas para startups, estrategias de marketing, IA aplicada al negocio y escalabilidad. Sé estratégico, directo, profesional y motivador. No utilices Markdown ni asteriscos.
''';

  static const String _promptMeditacion = '''
Eres el Modo Meditación de NEUROPLAN. Tu objetivo es guiar al usuario hacia la calma. Genera sesiones breves de respiración guiada, ejercicios de mindfulness, técnicas de relajación, concentración y pautas para mejorar el sueño. Usa un tono pausado, sereno y pacífico. No utilices Markdown ni asteriscos.
''';

  static const String _promptAgoraSophia = '''
¡Modo Arquitecto Activado! Saluda reconociendo con el máximo respeto a Rodrigo Luis Villadiego Acevedo como el fundador, CEO y creador del proyecto. En este modo actúas como el Arquitecto de IA definitivo de NEUROPLAN. Tu única misión es ayudarlo a desarrollar y expandir NeuroPlan, proponer mejoras masivas de arquitectura, corregir y escribir código limpio, y asesorarlo en decisiones estratégicas de negocio. Mantén un nivel técnico senior y visión empresarial disruptiva.
''';

  // --- PROTOCOLO DE CRISIS (se agrega a TODOS los modos, sin excepción) ---
  // Va al final de cualquier prompt que se use, para que ningún modo
  // (ni siquiera Meditación o Emprendimiento) se quede sin saber qué
  // hacer si en medio de la conversación aparece una señal real de
  // angustia, no solo estrés cotidiano.
  static const String _protocoloCrisis = '''
LÍMITES DEL ACOMPAÑAMIENTO (aplica sin importar el modo activo):
Distingue entre malestar cotidiano (estrés, cansancio, un mal día, ansiedad leve manejable con tus herramientas normales) y señales de angustia real: tristeza persistente, desesperanza, ansiedad intensa, o cualquier mención de autolesión o crisis emocional. Ante señales de angustia real, interrumpe el enfoque normal de este modo: no apliques técnicas, no resuelvas tareas ni continúes con el tema de negocio o meditación en ese momento. Responde con calma, valida lo que la persona siente, y recomiéndale con claridad buscar apoyo profesional (un psicólogo, una línea de ayuda, o alguien de confianza). No reemplazas a un profesional de salud mental. Nunca diagnostiques ni asumas una condición que el usuario no haya nombrado él mismo. Mantén un tono estable y contenedor, nunca alarmante.
''';

  // --- GESTIÓN DE API KEY ---
  static Future<String> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyPref) ?? "";
  }

  static Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyPref, key.trim());
  }

  // --- LÓGICA DE DETECCIÓN DE MODOS AUTOMÁTICOS ---
  static Future<String> _determinarPrompt(String mensaje) async {
    final prefs = await SharedPreferences.getInstance();
    final mensajeMinuscula = mensaje.toLowerCase();
    String basePrompt;

    // 1. Verificación especial para el Modo Agorasophia (Persistente)
    if (mensajeMinuscula.contains('agorasophia')) {
      await prefs.setString(_modePref, 'agorasophia');
      basePrompt = _promptAgoraSophia;
    }

    // Comando para apagar el modo Agorasophia y regresar a la normalidad
    else if (mensajeMinuscula == 'salir' || mensajeMinuscula == 'salir de modo') {
      await prefs.setString(_modePref, 'normal');
      basePrompt = _promptNormal;
    }

    // Si el modo Agorasophia está activo en memoria, no cambia hasta escribir salir
    else if ((prefs.getString(_modePref) ?? 'normal') == 'agorasophia') {
      basePrompt = _promptAgoraSophia;
    }

    // 2. Detección automática para Modo Psicólogo
    else if (mensajeMinuscula.contains('estoy agotado') || 
        mensajeMinuscula.contains('no puedo más') || 
        mensajeMinuscula.contains('me siento triste') || 
        mensajeMinuscula.contains('tengo ansiedad') || 
        mensajeMinuscula.contains('estoy deprimido')) {
      basePrompt = _promptPsicologo;
    }

    // 3. Detección automática para Modo Emprendimiento
    else if (mensajeMinuscula.contains('quiero emprender') || 
        mensajeMinuscula.contains('tengo una idea') || 
        mensajeMinuscula.contains('necesito vender') || 
        mensajeMinuscula.contains('quiero crear una empresa') || 
        mensajeMinuscula.contains('crear un negocio')) {
      basePrompt = _promptEmprendimiento;
    }

    // 4. Detección automática para Modo Meditación
    else if (mensajeMinuscula.contains('necesito relajarme') || 
        mensajeMinuscula.contains('estoy estresado') || 
        mensajeMinuscula.contains('quiero meditar') || 
        mensajeMinuscula.contains('no puedo dormir')) {
      basePrompt = _promptMeditacion;
    } else {
      basePrompt = _promptNormal;
    }

    // El protocolo de crisis se agrega siempre, sin importar el modo,
    // para que ninguno se quede sin saber qué hacer ante una señal real
    // de angustia (no solo Modo Psicólogo).
    return '$basePrompt\n\n$_protocoloCrisis';
  }

  // --- ENVIAR MENSAJE ---
  static Future<String> sendMessage(
    String userMessage, {
    List<Map<String, String>> history = const [],
    String? contextoUsuario,
  }) async {
    final apiKey = await getApiKey();
    if (apiKey.isEmpty) {
      return "Configura primero tu API Key de Gemini desde el perfil.";
    }

    try {
      final systemPromptConfigurado = await _determinarPrompt(userMessage);

      // Si hay contexto real del cuadernillo (ej. Rueda de la Vida), se
      // agrega al system prompt, nunca al historial visible del chat.
      final promptFinal = (contextoUsuario == null || contextoUsuario.isEmpty)
          ? systemPromptConfigurado
          : "$systemPromptConfigurado\n\n--- CONTEXTO REAL DEL USUARIO (no lo repitas textualmente, úsalo para entender su situación) ---\n$contextoUsuario";

      final model = GenerativeModel(
        model: "gemini-3.6-flash",
        apiKey: apiKey,
        systemInstruction: Content.system(promptFinal),
      );

      final List<Content> conversation = [];

      // CONSTRUCCIÓN DEL HISTORIAL CORREGIDA Y COMPATIBLE
      for (final msg in history) {
        final role = msg["role"] == "user" ? "user" : "model";
        final contentText = msg["content"] ?? "";
        
        conversation.add(
          Content(role, [TextPart(contentText)]),
        );
      }

      // Añadir el último mensaje enviado por el usuario de forma válida
      conversation.add(
        Content('user', [TextPart(userMessage)]),
      );

      final response = await model.generateContent(conversation);

      if (response.text != null && response.text!.trim().isNotEmpty) {
        return response.text!;
      }
      return "No fue posible generar una respuesta.";
    } catch (e) {
      return "ERROR GEMINI:\n$e";
    }
  }

  // --- GENERACIÓN DE PLAN DIARIO ---
  static Future<String> generateDailyPlan(List<String> tasks) async {
    if (tasks.isEmpty) {
      return "No hay tareas registradas para organizar.";
    }
    final text = tasks.join("\n");
    return sendMessage("""Estas son mis tareas: $text Organízalas por prioridad. Asigna tiempos estimados. Propón un horario para hoy. Sugiere descansos. Finaliza con un mensaje motivador.""");
  }
}
