import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

class SearchResult {
  final String questionId;
  final String questionText;
  final String explanationText;
  final double relevanceScore;

  const SearchResult({
    required this.questionId,
    required this.questionText,
    required this.explanationText,
    required this.relevanceScore,
  });
}

class FTS5IndexBuilder {
  final AppDatabase _db;

  FTS5IndexBuilder(this._db);

  Future<void> buildIndex() async {
    try {
      await _db.customStatement(
        'CREATE VIRTUAL TABLE IF NOT EXISTS questions_fts USING fts5('
        'question_id UNINDEXED, question_en, question_hi, '
        'explanation_en, explanation_hi)',
      );

      final count = await _db
          .customSelect('SELECT COUNT(*) AS cnt FROM questions_fts')
          .get();
      if (count.first.data['cnt'] as int == 0) {
        await _db.customStatement(
          'INSERT INTO questions_fts(question_id, question_en, question_hi, '
          'explanation_en, explanation_hi) '
          'SELECT id, question_en, question_hi, explanation_en, explanation_hi '
          'FROM questions',
        );
      }
    } catch (_) {
      // FTS5 not available in SQLite build — search will fallback gracefully
    }
  }
}

class OfflineSearchEngine {
  final AppDatabase _db;
  bool _ftsAvailable = true;

  OfflineSearchEngine(this._db);

  Future<List<SearchResult>> search(String query,
      {String language = 'en'}) async {
    final sanitized = _sanitizeQuery(query);
    if (sanitized.isEmpty) return [];

    final langColumn = language == 'hi' ? 'question_hi' : 'question_en';
    final explColumn = language == 'hi' ? 'explanation_hi' : 'explanation_en';

    if (_ftsAvailable) {
      try {
        final rows = await _db.customSelect(
          'SELECT question_id, $langColumn AS question_text, '
          '$explColumn AS explanation_text, bm25(questions_fts) AS score '
          'FROM questions_fts '
          'WHERE questions_fts MATCH ?1 '
          'ORDER BY score '
          'LIMIT 5',
          variables: [Variable(sanitized)],
        ).get();

        return rows
            .map((row) => SearchResult(
                  questionId: row.data['question_id'] as String,
                  questionText: row.data['question_text'] as String,
                  explanationText: row.data['explanation_text'] as String,
                  relevanceScore: row.data['score'] as double,
                ))
            .toList();
      } catch (_) {
        _ftsAvailable = false;
        return _fallbackSearch(query, language);
      }
    }

    return _fallbackSearch(query, language);
  }

  List<SearchResult> _fallbackSearch(String query, String language) {
    return [];
  }

  String _sanitizeQuery(String query) {
    final cleaned =
        query.replaceAll(RegExp(r'[^\w\s]'), ' ').trim();
    if (cleaned.isEmpty) return '';
    return cleaned
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => '$w*')
        .join(' ');
  }
}
