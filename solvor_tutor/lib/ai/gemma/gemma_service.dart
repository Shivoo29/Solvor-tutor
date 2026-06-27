import 'package:flutter_gemma/flutter_gemma.dart';

class GemmaService {
  GemmaService._();
  static final GemmaService instance = GemmaService._();

  static const String modelFileName = 'gemma-4-E2B-it-q4.litertlm';
  static const String modelUrl =
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it-q4.litertlm';

  InferenceModel? _model;
  InferenceChat? _activeChat;
  bool _disposed = false;

  bool get isModelLoaded => _model != null && !_disposed;

  void _reset() {
    _disposed = false;
    _model = null;
  }

  Future<bool> isModelInstalled() => FlutterGemma.isModelInstalled(modelFileName);

  Future<void> downloadModel({
    void Function(double progress)? onProgress,
  }) async {
    await FlutterGemma.installModel(
      modelType: ModelType.gemma4,
      fileType: ModelFileType.litertlm,
    ).fromNetwork(modelUrl).withProgress((progress) {
      onProgress?.call(progress / 100.0);
    }).install();
  }

  Future<void> loadModel() async {
    _reset(); // clear disposed flag so re-download works
    _model = await FlutterGemma.getActiveModel(
      maxTokens: 1024,
      preferredBackend: PreferredBackend.gpu,
    );
  }

  Stream<String> generateAnswer(String question) async* {
    if (_model == null || _disposed) {
      await loadModel();
    }

    final model = _model!;
    final chat = await model.createChat(
      systemInstruction:
          'You are Solvor Tutor, an AI assistant for SSC and Banking exam preparation in India. '
          'Answer concisely and accurately. Keep responses under 200 words. '
          'Use simple English. If the question is not about academics, politely redirect.',
    );

    await chat.addQueryChunk(Message.text(text: question, isUser: true));

    final buffer = StringBuffer();
    final stream = chat.generateChatResponseAsync();
    await for (final chunk in stream) {
      if (_disposed) break;
      if (chunk is TextResponse) {
        buffer.write(chunk.token);
        yield buffer.toString(); // always yield full accumulated text
      }
    }
  }

  Future<void> startTutorSession({String? systemPrompt}) async {
    if (_model == null || _disposed) await loadModel();
    _activeChat = await _model!.createChat(
      systemInstruction: systemPrompt ??
          'You are Solvy, a friendly personal AI tutor for SSC and Banking exam preparation in India. '
              'You guide students proactively — suggest topics, give examples, ask follow-up questions. '
              'Keep responses short (2-4 sentences). Use simple Hindi/English mix (Hinglish) when appropriate. '
              'After answering, always ask one follow-up: a practice question or "Kya yeh clear hua?"',
    );
  }

  Stream<String> sendTutorMessage(String userMessage) async* {
    if (_model == null || _disposed) await loadModel();
    _activeChat ??= await _model!.createChat(
      systemInstruction:
          'You are Solvy, a friendly personal AI tutor for SSC and Banking exam preparation in India. '
          'You guide students proactively — suggest topics, give examples, ask follow-up questions. '
          'Keep responses short (2-4 sentences). Use simple Hindi/English mix (Hinglish) when appropriate. '
          'After answering, always ask one follow-up: a practice question or "Kya yeh clear hua?"',
    );

    await _activeChat!.addQueryChunk(Message.text(text: userMessage, isUser: true));

    final buffer = StringBuffer();
    await for (final chunk in _activeChat!.generateChatResponseAsync()) {
      if (_disposed) break;
      if (chunk is TextResponse) {
        buffer.write(chunk.token);
        yield buffer.toString();
      }
    }
  }

  void endTutorSession() {
    _activeChat = null;
  }

  Future<void> uninstallModel() async {
    await dispose();
    await FlutterGemma.uninstallModel(modelFileName);
    await FlutterGemma.clearActiveInferenceIdentity();
  }

  Future<void> dispose() async {
    _disposed = true;
    _activeChat = null;
    await _model?.close();
    _model = null;
  }
}
