import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../ai/edge/intent_classifier.dart';
import '../../../../ai/search/offline_search.dart';
import '../ai_tutor_provider.dart';

class AiTutorScreen extends ConsumerStatefulWidget {
  const AiTutorScreen({super.key});

  @override
  ConsumerState<AiTutorScreen> createState() => _AiTutorScreenState();
}

class _AiTutorScreenState extends ConsumerState<AiTutorScreen> {
  final _controller = TextEditingController();
  String _query = '';

  void _submit() {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    setState(() => _query = q);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchAsync = ref.watch(aiTutorSearchProvider(_query));

    return Scaffold(
      appBar: AppBar(title: const Text('AI Tutor')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Ask anything about your exam...',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _submit,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ),
          Expanded(
            child: searchAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (state) {
                if (_query.isEmpty) {
                  return const Center(
                    child: Text(
                      'Type a question to search your study material',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                if (!state.hasResults) {
                  if (state.intent != IntentType.unknown) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _IntentBadge(label: state.intentLabel),
                          const SizedBox(height: 16),
                          const Text(
                            'Try rephrasing your question',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const Center(
                    child: Text(
                      'Try rephrasing your question',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    if (state.intent != IntentType.unknown)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _IntentBadge(label: state.intentLabel),
                      ),
                    ...state.results
                        .take(3)
                        .map((r) => _ResultCard(result: r)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _IntentBadge extends StatelessWidget {
  final String label;
  const _IntentBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome,
              size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatefulWidget {
  final SearchResult result;
  const _ResultCard({required this.result});

  @override
  State<_ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<_ResultCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(
            onTap: () => setState(() => _expanded = !_expanded),
            title: Text(
              widget.result.questionText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              'Relevance: ${widget.result.relevanceScore.toStringAsFixed(1)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
            trailing: Icon(
              _expanded ? Icons.expand_less : Icons.expand_more,
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Explanation:',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(widget.result.explanationText),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
