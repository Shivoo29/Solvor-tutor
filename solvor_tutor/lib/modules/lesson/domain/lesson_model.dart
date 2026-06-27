enum LessonStep { concept, example, quiz1, quiz2, quiz3, summary }

class LessonQuestion {
  final String text;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const LessonQuestion({
    required this.text,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}

class LessonModel {
  final String topic;
  final String concept;
  final String example;
  final List<LessonQuestion> questions;

  const LessonModel({
    required this.topic,
    required this.concept,
    required this.example,
    required this.questions,
  });
}

class LessonState {
  final bool loading;
  final String? error;
  final LessonModel? lesson;
  final LessonStep currentStep;
  final List<int?> answers;

  const LessonState({
    this.loading = true,
    this.error,
    this.lesson,
    this.currentStep = LessonStep.concept,
    this.answers = const [null, null, null],
  });

  int get correctCount => answers
      .asMap()
      .entries
      .where((e) =>
          e.value != null &&
          lesson != null &&
          e.key < lesson!.questions.length &&
          e.value == lesson!.questions[e.key].correctIndex)
      .length;

  LessonState copyWith({
    bool? loading,
    String? error,
    LessonModel? lesson,
    LessonStep? currentStep,
    List<int?>? answers,
  }) =>
      LessonState(
        loading: loading ?? this.loading,
        error: error ?? this.error,
        lesson: lesson ?? this.lesson,
        currentStep: currentStep ?? this.currentStep,
        answers: answers ?? this.answers,
      );
}
