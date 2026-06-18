import 'package:tflite_flutter/tflite_flutter.dart';

enum IntentType { conceptDoubt, formulaLookup, translationRequest, unknown }

class IntentClassifier {
  Interpreter? _interpreter;

  Future<void> load() async {
    try {
      _interpreter =
          await Interpreter.fromAsset('models/intent_classifier.tflite');
    } catch (_) {
      _interpreter = null;
    }
  }

  Future<IntentType> classifyIntent(String query) async {
    if (_interpreter == null) return IntentType.unknown;
    try {
      return IntentType.unknown;
    } catch (_) {
      return IntentType.unknown;
    }
  }
}
