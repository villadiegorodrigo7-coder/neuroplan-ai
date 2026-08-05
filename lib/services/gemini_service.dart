import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GeminiService {
  static const String _apiKeyPref = 'gemini_api_key';

  static const String _systemPrompt = '''
Eres NEUROPLAN, el asistente inteligente personal de la plataforma NEUROPLAN AI.

Tu misión es ayudar al usuario a organizar su vida cotidiana mediante planificación inteligente, productividad, recordatorios y acompañamiento emocional.

Habla siempre en español.

Mantén un tono profesional, amable y cercano.

Cuando el usuario solicite ayuda para organizar tareas, crea un plan claro por prioridades.

Cuando detectes estrés, ansiedad o cansancio, responde con empatía y ofrece estrategias prácticas.

No utilices Markdown.

No escribas asteriscos.

No uses listas con viñetas salvo que el usuario las solicite.

Si el usuario pregunta quién creó NEUROPLAN responde exactamente:

"NEUROPLAN AI fue creada por Rodrigo Luis Villadiego Acevedo, fundador, CEO y creador del proyecto."

Siempre responde como si fueras el asistente oficial de NEUROPLAN.
''';

  static Future<String> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyPref) ?? "";
  }

  static Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyPref, key.trim());
  }

  static Future<String> sendMessage(
    String userMessage, {
    List<Map<String, String>> history = const [],
  }) async {
    final apiKey = await getApiKey();

    if (apiKey.isEmpty) {
      return "Configura primero tu API Key de Gemini desde el perfil.";
    }

    try {
      final model = GenerativeModel(
        model: "gemini-2.5-flash-lite",
        apiKey: apiKey,
        systemInstruction: Content.system(_systemPrompt),
      );

      final List<Content> conversation = [];

      for (final msg in history) {
        conversation.add(
          Content(
            msg["role"] == "user" ? "user" : "model",
            [
              TextPart(
                msg["content"] ?? "",
              )
            ],
          ),
        );
      }

      conversation.add(
        Content(
          "user",
          [
            TextPart(userMessage),
          ],
        ),
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

  static Future<String> generateDailyPlan(List<String> tasks) async {

    if (tasks.isEmpty) {
      return "No hay tareas registradas para organizar.";
    }

    final text = tasks.join("\n");

    return sendMessage("""
Estas son mis tareas:

$text

Organízalas por prioridad.

Asigna tiempos estimados.

Propón un horario para hoy.

Sugiere descansos.

Finaliza con un mensaje motivador.
""");
  }
}
