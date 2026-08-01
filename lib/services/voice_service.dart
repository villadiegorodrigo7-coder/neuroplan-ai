import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

class VoiceService {
  static final stt.SpeechToText _speech = stt.SpeechToText();
  static final FlutterTts _tts = FlutterTts();
  static bool _ttsReady = false;

  static Future<void> _ensureTts() async {
    if (_ttsReady) return;
    await _tts.setLanguage('es-ES');
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);
    _ttsReady = true;
  }

  static Future<bool> initSpeech() async {
    return await _speech.initialize(
      onError: (error) => print('Error de voz: $error'),
      onStatus: (status) => print('Estado de voz: $status'),
    );
  }

  static bool get isListening => _speech.isListening;

  static Future<void> startListening({
    required Function(String text) onResult,
    required Function() onDone,
  }) async {
    final available = await initSpeech();
    if (!available) {
      onDone();
      return;
    }
    await _speech.listen(
      localeId: 'es_ES',
      onResult: (result) {
        if (result.finalResult) {
          onResult(result.recognizedWords);
          onDone();
        }
      },
    );
  }

  static Future<void> stopListening() async {
    await _speech.stop();
  }

  static Future<void> speak(String text) async {
    await _ensureTts();
    await _tts.stop();
    await _tts.speak(text);
  }

  static Future<void> stopSpeaking() async {
    await _tts.stop();
  }
}
