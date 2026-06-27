import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/mascot/mascot_widget.dart';
import '../lesson_provider.dart';

class LessonScreen extends ConsumerWidget {
  final String topic;
  const LessonScreen({super.key, required this.topic});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(lessonProvider(topic));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? kVoid : kPaper,
      appBar: AppBar(
        backgroundColor: isDark ? kSurface : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        title: Text(
          topic,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : kInk,
          ),
        ),
      ),
      body: state.loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  MascotWidget(emotion: MascotEmotion.thinking, size: 80),
                  const SizedBox(height: 20),
                  Text(
                    'Solvy padh raha hai...',
                    style: TextStyle(
                        color: isDark ? Colors.white54 : kMuted, fontSize: 14),
                  ),
                ],
              ),
            )
          : state.error != null
              ? Center(child: Text('Error: ${state.error}'))
              : _LessonContent(
                  state: state,
                  topic: topic,
                  isDark: isDark,
                  ref: ref,
                ),
    );
  }
}

class _LessonContent extends StatelessWidget {
  final LessonState state;
  final String topic;
  final bool isDark;
  final WidgetRef ref;

  const _LessonContent({
    required this.state,
    required this.topic,
    required this.isDark,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final lesson = state.lesson!;
    final notifier = ref.read(lessonProvider(topic).notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: _buildStep(context, lesson, notifier),
      ),
    );
  }

  Widget _buildStep(BuildContext context, LessonModel lesson, LessonNotifier notifier) {
    switch (state.currentStep) {
      case LessonStep.concept:
        return _StepCard(
          key: const ValueKey('concept'),
          mascotEmotion: MascotEmotion.greeting,
          label: 'CONCEPT',
          accentColor: kNeonTeal,
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(lesson.concept,
                  style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: isDark ? Colors.white70 : kInk)),
              const SizedBox(height: 20),
              _NextButton(label: 'Example dekho', onTap: notifier.nextStep, isDark: isDark),
            ],
          ),
        );

      case LessonStep.example:
        return _StepCard(
          key: const ValueKey('example'),
          mascotEmotion: MascotEmotion.happy,
          label: 'EXAMPLE',
          accentColor: kNeonYellow,
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                color: isDark ? kNeonYellow.withValues(alpha: 0.08) : kBorder,
                child: Text(lesson.example,
                    style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        fontStyle: FontStyle.italic,
                        color: isDark ? Colors.white70 : kInk)),
              ),
              const SizedBox(height: 20),
              _NextButton(
                  label: 'Practice karo',
                  onTap: notifier.nextStep,
                  isDark: isDark),
            ],
          ),
        );

      case LessonStep.quiz1:
      case LessonStep.quiz2:
      case LessonStep.quiz3:
        final qIdx = state.currentStep.index - 2;
        if (qIdx >= lesson.questions.length) {
          notifier.nextStep();
          return const SizedBox.shrink();
        }
        final q = lesson.questions[qIdx];
        final answered = state.answers[qIdx];
        return _QuizCard(
          key: ValueKey('quiz$qIdx'),
          question: q,
          questionNumber: qIdx + 1,
          totalQuestions: lesson.questions.length,
          answered: answered,
          isDark: isDark,
          onAnswer: (i) {
            notifier.answerQuestion(qIdx, i);
            Future.delayed(const Duration(milliseconds: 800), notifier.nextStep);
          },
        );

      case LessonStep.summary:
        return _SummaryCard(
          topic: topic,
          correct: state.correctCount,
          total: lesson.questions.length,
          isDark: isDark,
          context: context,
        );
    }
  }
}

class _StepCard extends StatelessWidget {
  final Widget child;
  final String label;
  final Color accentColor;
  final bool isDark;
  final MascotEmotion mascotEmotion;

  const _StepCard({
    super.key,
    required this.child,
    required this.label,
    required this.accentColor,
    required this.isDark,
    required this.mascotEmotion,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MascotWidget(emotion: mascotEmotion, size: 80),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? kSurface : Colors.white,
            border: Border(
              left: BorderSide(color: accentColor, width: 3),
              top: BorderSide(color: isDark ? kSubtle : kBorder),
              right: BorderSide(color: isDark ? kSubtle : kBorder),
              bottom: BorderSide(color: isDark ? kSubtle : kBorder),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: accentColor)),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      ],
    );
  }
}

class _QuizCard extends StatelessWidget {
  final LessonQuestion question;
  final int questionNumber;
  final int totalQuestions;
  final int? answered;
  final bool isDark;
  final ValueChanged<int> onAnswer;

  const _QuizCard({
    super.key,
    required this.question,
    required this.questionNumber,
    required this.totalQuestions,
    required this.answered,
    required this.isDark,
    required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MascotWidget(
          emotion: answered == null
              ? MascotEmotion.thinking
              : answered == question.correctIndex
                  ? MascotEmotion.celebrating
                  : MascotEmotion.sad,
          size: 80,
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? kSurface : Colors.white,
            border: Border(
              left: const BorderSide(color: kNeonPurple, width: 3),
              top: BorderSide(color: isDark ? kSubtle : kBorder),
              right: BorderSide(color: isDark ? kSubtle : kBorder),
              bottom: BorderSide(color: isDark ? kSubtle : kBorder),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('QUESTION $questionNumber / $totalQuestions',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: isDark ? kNeonPurple : kMuted)),
              const SizedBox(height: 14),
              Text(question.text,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                      color: isDark ? Colors.white : kInk)),
              const SizedBox(height: 16),
              ...question.options.asMap().entries.map((e) {
                final idx = e.key;
                final opt = e.value;
                final isCorrect = idx == question.correctIndex;
                final isSelected = answered == idx;
                Color? bg;
                Color borderColor = isDark ? kSubtle : kBorder;

                if (answered != null) {
                  if (isCorrect) {
                    bg = kNeonTeal.withValues(alpha: 0.2);
                    borderColor = kNeonTeal;
                  } else if (isSelected) {
                    bg = Colors.red.withValues(alpha: 0.15);
                    borderColor = Colors.red;
                  }
                }

                return GestureDetector(
                  onTap: answered == null ? () => onAnswer(idx) : null,
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: bg ?? (isDark ? kVoid : kPaper),
                      border: Border.all(color: borderColor),
                    ),
                    child: Text(opt,
                        style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white70 : kInk)),
                  ),
                );
              }),
              if (answered != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  color: isDark ? kNeonTeal.withValues(alpha: 0.08) : kBorder,
                  child: Text(question.explanation,
                      style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: isDark ? Colors.white70 : kInk)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String topic;
  final int correct;
  final int total;
  final bool isDark;
  final BuildContext context;

  const _SummaryCard({
    required this.topic,
    required this.correct,
    required this.total,
    required this.isDark,
    required this.context,
  });

  @override
  Widget build(BuildContext _) {
    final pct = total == 0 ? 0 : (correct / total * 100).round();
    final emotion = pct >= 60 ? MascotEmotion.celebrating : MascotEmotion.sad;
    final msg = pct >= 80
        ? 'Zabardast! $correct/$total sahi! Tum ready ho!'
        : pct >= 60
            ? 'Accha kiya! $correct/$total sahi. Thoda aur practice karo.'
            : 'Koi baat nahi. $correct/$total sahi. Dubara try karo!';

    return Column(
      children: [
        MascotWidget(emotion: emotion, size: 100),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? kSurface : Colors.white,
            border: Border(
              left: const BorderSide(color: kNeonYellow, width: 3),
              top: BorderSide(color: isDark ? kSubtle : kBorder),
              right: BorderSide(color: isDark ? kSubtle : kBorder),
              bottom: BorderSide(color: isDark ? kSubtle : kBorder),
            ),
          ),
          child: Column(
            children: [
              Text('$topic — Lesson Complete!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : kInk)),
              const SizedBox(height: 16),
              Text(msg,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: isDark ? Colors.white70 : kInk)),
              const SizedBox(height: 24),
              _NextButton(
                  label: 'Ghar wapas jao',
                  onTap: () => context.go('/home'),
                  isDark: isDark),
            ],
          ),
        ),
      ],
    );
  }
}

class _NextButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isDark;

  const _NextButton(
      {required this.label, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        color: isDark ? kNeonYellow : kInk,
        child: Text(
          label.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: isDark ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }
}
