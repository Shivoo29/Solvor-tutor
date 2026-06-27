import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/l10n/strings_provider.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../ai/edge/intent_classifier.dart';
import '../../../../ai/gemma/gemma_provider.dart';
import '../../../../ai/ocr/ocr_service.dart';
import '../../../../ai/paraphrase/explanation_paraphraser.dart';
import '../../../../ai/search/offline_search.dart';
import '../ai_tutor_provider.dart';

class AiTutorScreen extends ConsumerStatefulWidget {
  const AiTutorScreen({super.key});

  @override
  ConsumerState<AiTutorScreen> createState() => _AiTutorScreenState();
}

class _AiTutorScreenState extends ConsumerState<AiTutorScreen> {
  final _controller = TextEditingController();
  final _ocrService = OcrService();
  final _picker = ImagePicker();
  String _query = '';
  bool _ocrProcessing = false;
  String? _ocrRawText; // what OCR actually read

  void _submit() {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _query = q;
      // clear OCR banner if user manually edited
      if (_ocrRawText != null && _ocrRawText != q) _ocrRawText = null;
    });
  }

  Future<void> _captureAndOcr() async {
    setState(() => _ocrProcessing = true);
    try {
      final xFile = await _picker.pickImage(source: ImageSource.camera);
      if (xFile == null) return;
      final text = await _ocrService.extractText(File(xFile.path));
      if (text.trim().isNotEmpty) {
        _controller.text = text.trim();
        setState(() {
          _ocrRawText = text.trim();
          _query = text.trim();
        });
      } else {
        setState(() => _ocrRawText = '(nothing detected)');
      }
    } finally {
      if (mounted) setState(() => _ocrProcessing = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final searchAsync = ref.watch(aiTutorSearchProvider(_query));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? kVoid : kPaper,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        title: Text(AppStrings.get('home_ai_tutor', lang)),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Chat with Solvy',
            onPressed: () => context.push('/tutor-chat'),
          ),
        ],
      ),
      body: Column(
        children: [
          const PatternBanner(),
          // Search bar — flat, brutalist
          Container(
            color: isDark ? kSurface : Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? kVoid : kPaper,
                      border: Border.all(color: isDark ? kSubtle : kBorder),
                    ),
                    child: TextField(
                      controller: _controller,
                      style: TextStyle(color: isDark ? Colors.white : kInk),
                      decoration: InputDecoration(
                        hintText: AppStrings.get('ai_tutor_hint', lang),
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white24 : kMuted,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // OCR button
                GestureDetector(
                  onTap: _ocrProcessing ? null : _captureAndOcr,
                  child: Container(
                    width: 44,
                    height: 44,
                    color: isDark ? kSubtle : kBorder,
                    child: _ocrProcessing
                        ? const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : Icon(
                            Icons.camera_alt_outlined,
                            size: 20,
                            color: isDark ? Colors.white54 : kMuted,
                          ),
                  ),
                ),
                const SizedBox(width: 6),
                // Search button
                GestureDetector(
                  onTap: _submit,
                  child: Container(
                    width: 44,
                    height: 44,
                    color: isDark ? kNeonYellow : kInk,
                    child: Icon(
                      Icons.search,
                      size: 20,
                      color: isDark ? Colors.black : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: isDark ? kSubtle : kBorder),

          // OCR info banner — shown when last action was camera
          if (_ocrRawText != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              color: isDark ? kNeonYellow.withValues(alpha: 0.10) : kInk.withValues(alpha: 0.05),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.camera_alt_outlined, size: 14,
                      color: isDark ? kNeonYellow : kMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('OCR READ:',
                            style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: isDark ? kNeonYellow : kMuted,
                            )),
                        const SizedBox(height: 2),
                        Text(_ocrRawText!,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : kInk.withValues(alpha: 0.6),
                              fontStyle: FontStyle.italic,
                            )),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _ocrRawText = null),
                    child: Icon(Icons.close, size: 14,
                        color: isDark ? Colors.white24 : kMuted),
                  ),
                ],
              ),
            ),

          // Results
          Expanded(
            child: searchAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (state) {
                if (_query.isEmpty) {
                  return _EmptyState(
                    message: AppStrings.get('ai_tutor_empty', lang),
                    isDark: isDark,
                  );
                }

                if (!state.hasResults) {
                  return _GemmaFallbackView(
                    keywords: state.searchedKeywords,
                    intentLabel: state.intent != IntentType.unknown
                        ? state.intentLabel
                        : null,
                    query: _query,
                    isDark: isDark,
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (state.intent != IntentType.unknown) ...[
                      _IntentTag(label: state.intentLabel, isDark: isDark),
                      const SizedBox(height: 12),
                    ],
                    ...state.results.take(3).map(
                          (r) => _ResultCard(result: r, isDark: isDark),
                        ),
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

class _EmptyState extends StatelessWidget {
  final String message;
  final bool isDark;
  final String? intentLabel;

  const _EmptyState({
    required this.message,
    required this.isDark,
    this.intentLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (intentLabel != null) ...[
              _IntentTag(label: intentLabel!, isDark: isDark),
              const SizedBox(height: 20),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white38 : kMuted,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GemmaFallbackView extends ConsumerWidget {
  final List<String> keywords;
  final String? intentLabel;
  final String query;
  final bool isDark;

  const _GemmaFallbackView({
    required this.keywords,
    required this.isDark,
    this.intentLabel,
    required this.query,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gemmaState = ref.watch(gemmaDownloadStatusProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (intentLabel != null) ...[
            _IntentTag(label: intentLabel!, isDark: isDark),
            const SizedBox(height: 16),
          ],

          if (keywords.isNotEmpty) ...[
            Text('KEYWORDS SEARCHED',
                style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: isDark ? Colors.white38 : kMuted,
                )),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: keywords.map((k) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                color: isDark ? kSubtle : kBorder,
                child: Text(k,
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : kInk,
                    )),
              )).toList(),
            ),
            const SizedBox(height: 20),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(14),
              color: isDark ? kNeonYellow.withValues(alpha: 0.08) : kBorder,
              child: Row(
                children: [
                  Icon(Icons.warning_amber_outlined, size: 16,
                      color: isDark ? kNeonYellow : kMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No keywords found after filtering — OCR may have failed. Try better lighting or type manually.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? kNeonYellow.withValues(alpha: 0.8) : kInk,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Gemma download or streaming section
          _GemmaSection(
            state: gemmaState,
            query: query,
            isDark: isDark,
          ),

          const SizedBox(height: 16),
          Text(
            'TIP: Type your question manually for best results.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white24 : kMuted.withValues(alpha: 0.6),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _GemmaSection extends ConsumerWidget {
  final GemmaDownloadState state;
  final String query;
  final bool isDark;

  const _GemmaSection({
    required this.state,
    required this.query,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (state.status) {
      case GemmaDownloadStatus.notDownloaded:
        return _GemmaDownloadCta(isDark: isDark);
      case GemmaDownloadStatus.downloading:
        return _GemmaDownloading(
          progress: state.progress,
          isDark: isDark,
        );
      case GemmaDownloadStatus.ready:
        return _GemmaAnswerView(query: query, isDark: isDark);
      case GemmaDownloadStatus.error:
        return _GemmaErrorView(
          error: state.error,
          isDark: isDark,
        );
    }
  }
}

class _GemmaDownloadCta extends ConsumerWidget {
  final bool isDark;
  const _GemmaDownloadCta({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? kSurface : Colors.white,
        border: Border(
          top: BorderSide(color: isDark ? kSubtle : kBorder),
          right: BorderSide(color: isDark ? kSubtle : kBorder),
          bottom: BorderSide(color: isDark ? kSubtle : kBorder),
          left: const BorderSide(color: kNeonPurple, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ON-DEVICE AI (BETA)',
            style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: isDark ? kNeonPurple : kMuted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Gemma 4 (On-Device AI) — 1.5 GB download needed. '
            'Answer any question without internet.',
            style: TextStyle(
              fontSize: 13, height: 1.5,
              color: isDark ? Colors.white70 : kInk,
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () =>
                ref.read(gemmaDownloadStatusProvider.notifier).startDownload(),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              color: isDark ? kNeonYellow : kInk,
              child: Text(
                'DOWNLOAD GEMMA 4',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: isDark ? Colors.black : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GemmaDownloading extends StatelessWidget {
  final double progress;
  final bool isDark;

  const _GemmaDownloading({required this.progress, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? kSurface : Colors.white,
        border: Border(
          top: BorderSide(color: isDark ? kSubtle : kBorder),
          right: BorderSide(color: isDark ? kSubtle : kBorder),
          bottom: BorderSide(color: isDark ? kSubtle : kBorder),
          left: const BorderSide(color: kNeonPurple, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DOWNLOADING GEMMA 4',
            style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: isDark ? kNeonTeal : kMuted,
            ),
          ),
          const SizedBox(height: 10),
          ClipRect(
            child: Container(
              height: 6,
              color: isDark ? kSubtle : kBorder,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(color: kNeonTeal),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).toInt()}%',
            style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : kMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _GemmaAnswerView extends ConsumerWidget {
  final String query;
  final bool isDark;

  const _GemmaAnswerView({required this.query, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (query.isEmpty) return const SizedBox.shrink();

    final answerAsync = ref.watch(gemmaAnswerProvider(query));

    return answerAsync.when(
      loading: () => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? kSurface : Colors.white,
          border: Border(
            top: BorderSide(color: isDark ? kSubtle : kBorder),
            right: BorderSide(color: isDark ? kSubtle : kBorder),
            bottom: BorderSide(color: isDark ? kSubtle : kBorder),
            left: const BorderSide(color: kNeonPurple, width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GEMMA 4 ON-DEVICE',
              style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: kNeonPurple,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(
                  'Generating answer...',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : kMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      error: (e, _) => _GemmaErrorView(
        error: e.toString(),
        isDark: isDark,
      ),
      data: (answer) {
        if (answer.isEmpty) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? kSurface : Colors.white,
            border: Border(
              top: BorderSide(color: isDark ? kSubtle : kBorder),
              right: BorderSide(color: isDark ? kSubtle : kBorder),
              bottom: BorderSide(color: isDark ? kSubtle : kBorder),
              left: const BorderSide(color: kNeonPurple, width: 3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'GEMMA 4 ON-DEVICE',
                    style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: kNeonPurple,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.memory, size: 13, color: isDark ? kNeonPurple : kMuted),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                answer,
                style: TextStyle(
                  fontSize: 13, height: 1.6,
                  color: isDark ? Colors.white70 : kInk.withOpacity(0.85),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GemmaErrorView extends ConsumerWidget {
  final String? error;
  final bool isDark;

  const _GemmaErrorView({this.error, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? kSurface : Colors.white,
        border: Border(
          top: BorderSide(color: isDark ? kSubtle : kBorder),
          right: BorderSide(color: isDark ? kSubtle : kBorder),
          bottom: BorderSide(color: isDark ? kSubtle : kBorder),
          left: const BorderSide(color: Colors.red, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GEMMA 4 ERROR',
            style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: isDark ? Colors.red[300] : Colors.red[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error ?? 'An unknown error occurred.',
            style: TextStyle(
              fontSize: 12, height: 1.4,
              color: isDark ? Colors.white54 : kMuted,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () =>
                ref.read(gemmaDownloadStatusProvider.notifier).startDownload(),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: isDark ? kNeonYellow : kInk,
              child: Text(
                'RETRY',
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: isDark ? Colors.black : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntentTag extends StatelessWidget {
  final String label;
  final bool isDark;

  const _IntentTag({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      color: isDark ? kNeonPurple.withOpacity(0.2) : kInk.withOpacity(0.06),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 13,
            color: isDark ? kNeonPurple : kMuted,
          ),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: isDark ? kNeonPurple : kMuted,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatefulWidget {
  final SearchResult result;
  final bool isDark;

  const _ResultCard({required this.result, required this.isDark});

  @override
  State<_ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<_ResultCard> {
  bool _expanded = false;
  ParaphraseMode _paraphraseMode = ParaphraseMode.short;
  final _paraphraser = ExplanationParaphraser();

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? kSurface : Colors.white,
        border: Border.all(color: isDark ? kSubtle : kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.result.questionText,
                      maxLines: _expanded ? null : 2,
                      overflow: _expanded ? null : TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : kInk,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: isDark ? Colors.white38 : kMuted,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Container(height: 1, color: isDark ? kSubtle : kBorder),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'EXPLANATION',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          color: isDark ? kNeonTeal : kMuted,
                        ),
                      ),
                      const Spacer(),
                      _ModeToggle(
                        mode: _paraphraseMode,
                        isDark: isDark,
                        onChanged: (m) => setState(() => _paraphraseMode = m),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _paraphraser.paraphrase(
                      widget.result.explanationText,
                      mode: _paraphraseMode,
                    ),
                    style: TextStyle(
                      color: isDark ? Colors.white70 : kInk.withOpacity(0.85),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  final ParaphraseMode mode;
  final bool isDark;
  final ValueChanged<ParaphraseMode> onChanged;

  const _ModeToggle({
    required this.mode,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Chip(
          label: 'Short',
          active: mode == ParaphraseMode.short,
          isDark: isDark,
          onTap: () => onChanged(ParaphraseMode.short),
        ),
        const SizedBox(width: 4),
        _Chip(
          label: 'Simple',
          active: mode == ParaphraseMode.simplified,
          isDark: isDark,
          onTap: () => onChanged(ParaphraseMode.simplified),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final bool isDark;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.active,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        color: active
            ? (isDark ? kNeonTeal : kInk)
            : (isDark ? kSubtle : kBorder),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.w700 : FontWeight.normal,
            color: active
                ? (isDark ? Colors.black : Colors.white)
                : (isDark ? Colors.white38 : kMuted),
          ),
        ),
      ),
    );
  }
}
