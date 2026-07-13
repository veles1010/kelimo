import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

abstract interface class TtsEngine {
  Future<void> configure({
    required String language,
    required double speechRate,
    required double volume,
    required double pitch,
  });

  Future<bool> speak(String text);

  Future<void> stop();
}

class FlutterTtsEngine implements TtsEngine {
  FlutterTtsEngine({FlutterTts? flutterTts})
    : _flutterTts = flutterTts ?? FlutterTts();

  final FlutterTts _flutterTts;

  @override
  Future<void> configure({
    required String language,
    required double speechRate,
    required double volume,
    required double pitch,
  }) async {
    await _flutterTts.setLanguage(language);
    await _flutterTts.setSpeechRate(speechRate);
    await _flutterTts.setVolume(volume);
    await _flutterTts.setPitch(pitch);
    await _flutterTts.awaitSpeakCompletion(true);
  }

  @override
  Future<bool> speak(String text) async => await _flutterTts.speak(text) == 1;

  @override
  Future<void> stop() async {
    await _flutterTts.stop();
  }
}

class EnglishTtsService {
  EnglishTtsService({TtsEngine? engine})
    : _engine = engine ?? FlutterTtsEngine();

  static const language = 'en-US';
  static const speechRate = 0.42;
  static const volume = 1.0;
  static const pitch = 1.0;

  final TtsEngine _engine;
  final ValueNotifier<bool> isSpeaking = ValueNotifier(false);

  bool _isConfigured = false;
  bool _isDisposed = false;
  int _operationId = 0;

  Future<bool> speak(String text) async {
    if (_isDisposed || text.trim().isEmpty) return false;
    if (isSpeaking.value) return true;

    final operationId = ++_operationId;
    isSpeaking.value = true;

    try {
      if (!_isConfigured) {
        await _engine.configure(
          language: language,
          speechRate: speechRate,
          volume: volume,
          pitch: pitch,
        );
        _isConfigured = true;
      }

      await _engine.stop();
      final didSpeak = await _engine.speak(text);
      return operationId == _operationId ? didSpeak : true;
    } catch (_) {
      return operationId == _operationId && !_isDisposed ? false : true;
    } finally {
      if (!_isDisposed && operationId == _operationId) {
        isSpeaking.value = false;
      }
    }
  }

  Future<void> stop() async {
    if (_isDisposed) return;

    _operationId++;
    try {
      await _engine.stop();
    } catch (_) {
      // Stopping is best-effort when the platform TTS engine is unavailable.
    } finally {
      if (!_isDisposed) isSpeaking.value = false;
    }
  }

  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;
    _operationId++;
    try {
      await _engine.stop();
    } catch (_) {
      // Platform channels may already be detached while the screen closes.
    }
    isSpeaking.dispose();
  }
}
