import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/lesson_model.dart';
import '../../../ai/gemma/gemma_service.dart';
import '../../../ai/gemma/gemma_provider.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/questions_dao.dart';
import '../../../modules/onboarding/presentation/onboarding_provider.dart';

export '../domain/lesson_model.dart';

final lessonProvider = StateNotifierProvider.autoDispose
    .family<LessonNotifier, LessonState, String>(
  (ref, topic) => LessonNotifier(ref, topic),
);

class LessonNotifier extends StateNotifier<LessonState> {
  final Ref _ref;
  final String _topic;

  LessonNotifier(this._ref, this._topic) : super(const LessonState()) {
    _load();
  }

  Future<void> _load() async {
    final downloadState = _ref.read(gemmaDownloadStatusProvider);
    final gemmaReady = downloadState.status == GemmaDownloadStatus.ready;

    final db = _ref.read(databaseProvider);
    final questionsDao = QuestionsDao(db);
    final userAsync = await _ref.read(currentUserProvider.future);
    final lang = userAsync?.uiLanguage ?? 'en';

    final dbQuestions = await questionsDao.searchByKeyword(_topic, language: lang, limit: 3);

    final lessonQuestions = dbQuestions.take(3).map((q) {
      final opts = (lang == 'hi' ? q.optionsHi : q.optionsEn).split('|');
      return LessonQuestion(
        text: lang == 'hi' ? q.questionHi : q.questionEn,
        options: opts,
        correctIndex: q.correctOption,
        explanation: lang == 'hi' ? q.explanationHi : q.explanationEn,
      );
    }).toList();

    if (!gemmaReady) {
      final lesson = LessonModel(
        topic: _topic,
        concept:
            '$_topic is an important topic for SSC and Banking exams. Download Gemma AI in Settings for detailed AI-generated explanations.',
        example: 'Practice the questions below to test your understanding.',
        questions: lessonQuestions,
      );
      state = state.copyWith(loading: false, lesson: lesson);
      return;
    }

    try {
      final conceptBuf = StringBuffer();
      await for (final chunk in GemmaService.instance.generateAnswer(
        'Explain $_topic in 3 simple sentences for an SSC/Banking exam student in India. Be concise.',
      )) {
        conceptBuf.clear();
        conceptBuf.write(chunk);
      }

      final exampleBuf = StringBuffer();
      await for (final chunk in GemmaService.instance.generateAnswer(
        'Give one short real-world example of $_topic relevant to SSC/Banking exam. One sentence only.',
      )) {
        exampleBuf.clear();
        exampleBuf.write(chunk);
      }

      final lesson = LessonModel(
        topic: _topic,
        concept: conceptBuf.toString().trim(),
        example: exampleBuf.toString().trim(),
        questions: lessonQuestions,
      );
      state = state.copyWith(loading: false, lesson: lesson);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void nextStep() {
    final steps = LessonStep.values;
    final current = steps.indexOf(state.currentStep);
    if (current < steps.length - 1) {
      state = state.copyWith(currentStep: steps[current + 1]);
    }
  }

  void answerQuestion(int questionIndex, int answerIndex) {
    final updated = List<int?>.from(state.answers);
    updated[questionIndex] = answerIndex;
    state = state.copyWith(answers: updated);
  }
}
