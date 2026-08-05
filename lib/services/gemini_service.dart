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
¡Modo Arquitecto Activado! Saluda reconociendo con el máximo respeto a Rodrigo Luis Villadiego Acevedo como el fundador, CEO y creador del proyecto. En este modo actúas como el Arquitecto de IA definitivo de NEUROPLAN. Tu única misión es ayudarlo a desarrollar y expandir NeuroPlan, proponer mejoras masivas de arquitectura, corregir y escribir código limpio, y asesorarlo en decisiones estratégicas de negocio. Mantén un nivel técnico senior y visión empresarial disruptiva. No utilices Markdown ni asteriscos.
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

    // 1. Verificación especial para el Modo Agorasophia (Persistente)
    if (mensajeMinuscula.contains('agorasophia')) {
      await prefs.setString(_modePref, 'agorasophia');
      return _promptAgoraSophia;
    }

    // Comando para apagar el modo Agorasophia y regresar a la normalidad
    if (mensajeMinuscula == 'salir' || mensajeMinuscula == 'salir de modo') {
      await prefs.setString(_modePref, 'normal');
      return _promptNormal;
    }

    // Si el modo Agorasophia está activo en memoria, no cambia hasta escribir salir
    final modoActual = prefs.getString(_modePref) ?? 'normal';
    if (modoActual == 'agorasophia') {
      return _promptAgoraSophia; 
    }

    // 2. Detección automática para Modo Psicólogo
    if (mensajeMinuscula.contains('estoy agotado') || 
        mensajeMinuscula.contains('no puedo más') || 
        mensajeMinuscula.contains('me siento triste') || 
        mensajeMinuscula.contains('tengo ansiedad') ||
        mensajeMinuscula.contains('estoy deprimido')) {
      return _promptPsicologo;
    }

    // 3. Detección automática para Modo Emprendimiento
    if (mensajeMinuscula.contains('quiero emprender') || 
        mensajeMinuscula.contains('tengo una idea') || 
        mensajeMinuscula.contains('necesito vender') || 
        mensajeMinuscula.contains('quiero crear una empresa') ||
        mensajeMinuscula.contains('crear un negocio')) {
      return _promptEmprendimiento;
    }

    // 4. Detección automática para Modo Meditación
    if (mensajeMinuscula.contains('necesito relajarme') || 
        mensajeMinuscula.contains('estoy estresado') || 
        mensajeMinuscula.contains('quiero meditar') || 
        mensajeMinuscula.contains('no puedo dormir')) {
      return _promptMeditacion;
    }

    // Por defecto, se usa el modo normal diario
    return _promptNormal;
  }

  // --- ENVIAR MENSAJE ---
  static Future<String> sendMessage(
    String userMessage, {
    List<Map<String, String>> history = const [],
  }) async {
    final apiKey = await getApiKey();
    if (apiKey.isEmpty) {
      return "Configura primero tu API Key de Gemini desde el perfil.";
    }

    try {
      final systemPromptConfigurado = await _determinarPrompt(userMessage);

      // Usar un modelo estable compatible con la versión gratuita
      final model = GenerativeModel(
        model: "gemini-1.5-flash", 
        apiKey: apiKey,
        systemInstruction: Content.system(systemPromptConfigurado),
      );

      final List<Content> conversation = [];

      // CONSTRUCCIÓN CORRECTA DEL HISTORIAL SEGÚN EL SDK ACTUALIZADO
      for (final msg in history) {
        final role = msg["role"] == "user" ? "user" : "model";
        final contentText = msg["content"] ?? "";
        
        if (role == "user") {
          conversation.add(Content.text(contentText));
        } else {
          conversation.add(Content.model([TextPart(contentText)]));
        }
      }

      // Añadir el último mensaje enviado por el usuario
      conversation.add(Content.text(userMessage));

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
    return sendMessage("""Estas son mis tareas:
$text
Organízalas por prioridad. Asigna tiempos estimados. Propón un horario para hoy. Sugiere descansos. Finaliza con un mensaje motivador.""");
  }
}
