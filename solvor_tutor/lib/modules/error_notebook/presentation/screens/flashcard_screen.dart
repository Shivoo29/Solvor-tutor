import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/error_notebook_repository.dart';
import '../error_notebook_provider.dart';

class FlashcardScreen extends ConsumerStatefulWidget {
  const FlashcardScreen({super.key});

  @override
  ConsumerState<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends ConsumerState<FlashcardScreen> {
  int _currentIndex = 0;
  bool _showAnswer = false;
  late List<ReviewQueueItem> _items;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra;
    if (extra is List<ReviewQueueItem>) {
      _items = extra;
    } else {
      _items = [];
    }
  }

  ReviewQueueItem? get _current =>
      _currentIndex < _items.length ? _items[_currentIndex] : null;

  Future<void> _submitReview(bool wasCorrect) async {
    if (_current == null) return;
    await ref
        .read(errorNotebookRepositoryProvider)
        .submitReview(_current!.id, wasCorrect);
    setState(() {
      _currentIndex++;
      _showAnswer = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Flashcard Review')),
        body: const Center(child: Text('No cards to review')),
      );
    }

    if (_current == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Flashcard Review'),
          leading: IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              ref.invalidate(errorNotebookProvider);
              context.go('/error-notebook');
            },
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.celebration, size: 72, color: Colors.amber),
              const SizedBox(height: 16),
              Text(
                'All done for today!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Great job reviewing your mistakes.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  ref.invalidate(errorNotebookProvider);
                  context.go('/error-notebook');
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to Notebook'),
              ),
            ],
          ),
        ),
      );
    }

    final q = _current!.question;
    final optionsEn =
        List<String>.from(jsonDecode(q.optionsEn) as List);
    final labels = ['A', 'B', 'C', 'D'];

    return Scaffold(
      appBar: AppBar(
        title: Text('Card ${_currentIndex + 1} of ${_items.length}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.invalidate(errorNotebookProvider);
            context.go('/error-notebook');
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(
              value: (_currentIndex + 1) / _items.length,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Question',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        q.questionEn,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 16),
                      ...optionsEn.asMap().entries.map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      labels[e.key],
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(e.value)),
                                ],
                              ),
                            ),
                          ),
                      if (!_showAnswer) ...[
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () =>
                              setState(() => _showAnswer = true),
                          icon: const Icon(Icons.visibility),
                          label: const Text('Show Answer'),
                          style: ElevatedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ],
                      if (_showAnswer) ...[
                        const Divider(height: 32),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.check_circle,
                                      color: Colors.green[700], size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Correct Answer: ${labels[q.correctOption]}. ${optionsEn[q.correctOption]}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[800],
                                    ),
                                  ),
                                ],
                              ),
                              if (q.explanationEn.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  q.explanationEn,
                                  style: TextStyle(
                                      color: Colors.green[900]),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (q.shortcutFormulaNote != null &&
                            q.shortcutFormulaNote!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: Colors.blue[200]!),
                            ),
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.lightbulb,
                                    size: 18, color: Colors.blue[700]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    q.shortcutFormulaNote!,
                                    style: TextStyle(
                                      color: Colors.blue[900],
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (q.commonMistakeNote != null &&
                            q.commonMistakeNote!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.orange[200]!),
                            ),
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.warning_amber,
                                    size: 18,
                                    color: Colors.orange[700]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    q.commonMistakeNote!,
                                    style: TextStyle(
                                      color: Colors.orange[900],
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (_showAnswer) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _submitReview(false),
                      icon: const Icon(Icons.refresh, color: Colors.red),
                      label: const Text('Review Again',
                          style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _submitReview(true),
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Got it'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
