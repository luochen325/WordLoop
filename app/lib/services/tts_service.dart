import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  Future<void> init() async {
    if (kIsWeb) return;
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    if (!_ready) await init();
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      // 设备没有 TTS 引擎时静默失败
    }
  }
}
