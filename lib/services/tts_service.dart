import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  TtsService._();

  static final FlutterTts _tts = FlutterTts();
  static bool _ready = false;

  static Future<void> _ensureReady() async {
    if (_ready) return;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    if (Platform.isIOS) {
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          IosTextToSpeechAudioCategoryOptions.duckOthers,
        ],
      );
    }

    _ready = true;
  }

  static Future<void> speak(String text) async {
    await _ensureReady();
    await _tts.stop();
    await _tts.speak(text);
  }
}
