import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_state.dart';
import '../../../../core/database/daos/users_dao.dart';
import '../../../../core/theme/design_tokens.dart';
import '../test_provider.dart';
import '../widgets/confidence_selector.dart';
import '../widgets/question_card.dart';
import '../widgets/timer_bar.dart';

class TestScreen extends ConsumerStatefulWidget {
  final String testId;

  const TestScreen({super.key, required this.testId});

  @override
  ConsumerState<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends ConsumerState<TestScreen>
    with WidgetsBindingObserver {
  int _answerStartTime = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _answerStartTime = DateTime.now().millisecondsSinceEpoch;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    final notifier = ref.read(testProvider(widget.testId).notifier);
    notifier.onAppLifecycleChange(lifecycle);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(testProvider(widget.testId));
    final notifier = ref.read(testProvider(widget.testId).notifier);

    if (state.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final session = state.session;
    if (session == null || state.error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: ${state.error ?? "Session not found"}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/home'),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      );
    }

    final q = session.currentQuestion;
    final answer = session.currentAnswer;
    final conf = session.currentConfidence;
    final timeLimit = session.questions.length; // 1 min per q average

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/home');
      },
      child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        title: Text('Q ${session.currentIndex + 1}/${session.totalQuestions}'),
        centerTitle: true,
        actions: [
          TimerBar(
            elapsedSeconds: state.timeInSeconds,
            totalMinutes: 20,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
            child: Text(
              q.subjectTag,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  QuestionCard(
                    questionText: q.questionEn,
                    options: q.optionsEn,
                    selectedOption: answer,
                    onOptionSelected: (index) {
                      setState(() {
                        final now = DateTime.now().millisecondsSinceEpoch;
                        final timeTaken = (now - _answerStartTime) ~/ 1000;
                        if (session.currentAnswer == null) {
                          session.timeTaken[q.id] = timeTaken;
                        }
                        _answerStartTime = now;
                      });
                      notifier.selectAnswer(index);
                    },
                  ),
                  if (answer != null) ...[
                    const SizedBox(height: 16),
                    ConfidenceSelector(
                      selected: conf,
                      onSelected: (level) => notifier.setConfidence(level),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Builder(builder: (context) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? kSurface : Colors.white,
              border: Border(top: BorderSide(color: isDark ? kSubtle : kBorder)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  if (session.currentIndex > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => notifier.goToPreviousQuestion(),
                        child: const Text('Previous'),
                      ),
                    ),
                  if (session.currentIndex > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: (answer != null && conf != null)
                          ? () async {
                              if (session.isLastQuestion) {
                                final testId = await notifier.submitTest();
                                if (context.mounted) {
                                  context.go('/debrief/$testId');
                                }
                              } else {
                                await notifier.submitCurrentAnswer();
                                notifier.goToNextQuestion();
                                setState(() {
                                  _answerStartTime =
                                      DateTime.now().millisecondsSinceEpoch;
                                });
                              }
                            }
                          : null,
                      child: Text(
                          session.isLastQuestion ? 'Submit Test' : 'Next'),
                    ),
                  ),
                ],
              ),
            ),
          );}),
        ],
      ),
    ));
  }
}
