import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ai/edge/intent_classifier.dart';
import '../../../ai/search/offline_search.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/users_dao.dart';

final intentClassifierProvider = FutureProvider<IntentClassifier>((ref) async {
  final classifier = IntentClassifier();
  await classifier.load();
  return classifier;
});

final offlineSearchEngineProvider = Provider<OfflineSearchEngine>((ref) {
  final db = ref.watch(databaseProvider);
  return OfflineSearchEngine(db);
});

final aiTutorSearchProvider =
    FutureProvider.autoDispose.family<AiTutorSearchState, String>(
        (ref, query) async {
  if (query.trim().isEmpty) {
    return const AiTutorSearchState(
      intent: IntentType.unknown,
      results: [],
      language: 'en',
    );
  }

  final classifier = await ref.watch(intentClassifierProvider.future);
  final intent = await classifier.classifyIntent(query);

  final db = ref.watch(databaseProvider);
  final usersDao = UsersDao(db);
  final user = await usersDao.getUser();
  final language = user?.uiLanguage ?? 'en';

  final engine = ref.watch(offlineSearchEngineProvider);
  final results = await engine.search(query, language: language);

  return AiTutorSearchState(
    intent: intent,
    results: results,
    language: language,
  );
});

class AiTutorSearchState {
  final IntentType intent;
  final List<SearchResult> results;
  final String language;

  const AiTutorSearchState({
    this.intent = IntentType.unknown,
    this.results = const [],
    this.language = 'en',
  });

  String get intentLabel {
    switch (intent) {
      case IntentType.conceptDoubt:
        return 'Concept Doubt';
      case IntentType.formulaLookup:
        return 'Formula Lookup';
      case IntentType.translationRequest:
        return 'Translation';
      case IntentType.unknown:
        return '';
    }
  }

  bool get hasResults => results.isNotEmpty;
}
