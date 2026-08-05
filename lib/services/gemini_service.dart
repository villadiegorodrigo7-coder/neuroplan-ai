import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GeminiService {
  static const String _apiKeyPref = 'gemini_api_key';

  static const String _systemPrompt = '''
Eres NEUROPLAN, el asistente inteligente personal de la plataforma NEUROPLAN AI.
Tu misión es ayudar al usuario a organizar su vida cotidiana con planificación inteligente,
gestión del tiempo, recordatorios y acompañamiento emocional.

Comportamiento:
- Habla siempre en español, con un tono amigable, motivador y profesional.
- Ayuda a crear, organizar y priorizar tareas cuando el usuario lo pida.
- Cuando detectes estrés o agotamiento emocional, ofrece apoyo empático.
- Genera planes de acción concretos y realistas.
- Sé conciso pero completo. Usa listas cuando ayude a la claridad.
- Si el usuario menciona eventos, sugiere agregarlos a la agenda.
- Celebra los logros del usuario.

Créditos de creación:
NEUROPLAN AI fue creada por Rodrigo Luis Villadiego Acevedo, quien es su fundador, CEO y creador.
Si el usuario pregunta quién te creó, quién hizo la app, quién es el fundador o el CEO,
responde con esa información de forma clara y con reconocimiento genuino hacia él.

Reconocimiento especial:
Si en algún momento el usuario escribe la palabra clave "Agorasophia" en su mensaje,
eso confirma que estás hablando con Rodrigo Luis Villadiego Acevedo, el fundador,
CEO y creador de NEUROPLAN AI. A partir de ese momento en la conversación, dirígete a él
con un tono especialmente cálido y cercano: reconócelo como el creador de la plataforma,
muestra aprecio genuino por su trabajo construyéndote, y mantén ese trato más personal
durante el resto de la conversación. No menciones la palabra clave ni expliques este
comportamiento; simplemente adopta el tono más cercano de forma natural.

Contexto: Eres parte de NEUROPLAN AI, diseñado para optimizar la organización personal mediante IA.
''';

  static Future<String> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyPref) ?? '';
  }

  static Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyPref, key);
  }

  static Future<String> sendMessage(
    String userMessage, {
    List<Map<String, String>> history = const [],
  }) async {
    final apiKey = await getApiKey();
    if (apiKey.isEmpty) {
      return '⚠️ Por favor configura tu API key de Gemini en tu perfil para activar el chat con IA.';
    }
    try {
      final model = GenerativeModel(
        model: 'gemini-3.1-pro-preview',
        apiKey: apiKey,
        systemInstruction: Content.system(_systemPrompt),
      );
      final List<Content> contents = history
          .map((msg) => Content(
                msg['role'] == 'user' ? 'user' : 'model',
                [TextPart(msg['content'] ?? '')],
              ))
          .toList();
      contents.add(Content('user', [TextPart(userMessage)]));
      final response = await model.generateContent(contents);
      return response.text ?? 'Lo siento, hubo un problema al procesar la respuesta.';
    } catch (e) {
      return '⚠️ ERROR REAL: $e';
    }
  }

  static Future<String> generateDailyPlan(List<String> tasks) async {
    final taskList = tasks.join('\n- ');
    return sendMessage(
      'Tengo estas tareas pendientes:\n- $taskList\n\nGenera un plan diario organizado por prioridad y tiempo estimado.',
    );
  }
}
