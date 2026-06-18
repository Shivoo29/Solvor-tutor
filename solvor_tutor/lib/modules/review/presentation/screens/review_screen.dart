import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/review_repository.dart';
import '../../../error_notebook/presentation/error_notebook_provider.dart';
import '../review_provider.dart';
import '../widgets/explanation_card.dart';

class ReviewScreen extends ConsumerWidget {
  final String testId;

  const ReviewScreen({super.key, required this.testId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(reviewDataProvider(testId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Review'),
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/home'),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
        data: (data) {
          if (data.totalQuestions == 0) {
            return const Center(child: Text('No data available'));
          }

          final quadrants = data.speedAccuracyQuadrants;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SummaryCard(
                  score: data.correctCount,
                  total: data.totalQuestions,
                  accuracy: data.accuracy,
                  avgTime: data.avgTimePerQuestion,
                ),
                const SizedBox(height: 16),
                _SpeedAccuracyCard(quadrants: quadrants),
                const SizedBox(height: 16),
                Text(
                  'Question Review',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                ...data.questions.map((q) {
                  final attempt = data.attempts[q.id];
                  final isCorrect = attempt?.isCorrect ?? false;
                  final optionsEn =
                      List<String>.from(jsonDecode(q.optionsEn) as List);
                  final explanation = q.explanationEn;

                  return ExplanationCard(
                    questionText: q.questionEn,
                    options: optionsEn,
                    correctOption: q.correctOption,
                    selectedOption: attempt?.selectedOption,
                    isCorrect: isCorrect,
                    explanation: explanation,
                    shortcutFormulaNote: q.shortcutFormulaNote,
                    commonMistakeNote: q.commonMistakeNote,
                    showAddToNotebook: !isCorrect,
                    onAddToNotebook: () {
                      ref
                          .read(errorNotebookRepositoryProvider)
                          .triggerSchedule(q.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Added to Error Notebook'),
                        ),
                      );
                    },
                  );
                }),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => context.go('/home'),
                  icon: const Icon(Icons.home),
                  label: const Text('Back to Home'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int score;
  final int total;
  final double accuracy;
  final double avgTime;

  const _SummaryCard({
    required this.score,
    required this.total,
    required this.accuracy,
    required this.avgTime,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Test Complete!',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatItem(
                  label: 'Score',
                  value: '$score/$total',
                  color: Theme.of(context).colorScheme.primary,
                ),
                _StatItem(
                  label: 'Accuracy',
                  value: '${(accuracy * 100).toInt()}%',
                  color: accuracy >= 0.6 ? Colors.green : Colors.orange,
                ),
                _StatItem(
                  label: 'Avg Time',
                  value: '${avgTime.toInt()}s',
                  color: Colors.grey[700]!,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: accuracy,
                minHeight: 10,
                backgroundColor: Colors.grey[200],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _SpeedAccuracyCard extends StatelessWidget {
  final Map<String, int> quadrants;

  const _SpeedAccuracyCard({required this.quadrants});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Speed vs Accuracy',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _QuadrantBox(
                    label: 'Fast +\nCorrect',
                    count: quadrants['Fast+Correct'] ?? 0,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuadrantBox(
                    label: 'Slow +\nCorrect',
                    count: quadrants['Slow+Correct'] ?? 0,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _QuadrantBox(
                    label: 'Fast +\nWrong',
                    count: quadrants['Fast+Wrong'] ?? 0,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuadrantBox(
                    label: 'Slow +\nWrong',
                    count: quadrants['Slow+Wrong'] ?? 0,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuadrantBox extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _QuadrantBox({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
