import 'dart:convert';
import 'dart:async';

import 'package:drift/drift.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:http/http.dart' as http;

import 'app.dart';
import 'ai/search/offline_search.dart';
import 'core/database/app_database.dart';
import 'firebase_options.dart';
import 'sync/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FlutterGemma.initialize(
    inferenceEngines: const [LiteRtLmEngine()],
    maxDownloadRetries: 5,
  );

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final db = AppDatabase(buildConnection());
  await _loadSeedDataIfNeeded(db);

  final apiBase = String.fromEnvironment('API_BASE', defaultValue: 'https://api.solvor.co.in');

  // Fire-and-forget wake-up ping — warms Render cold start while user sees splash
  unawaited(http.get(Uri.parse('$apiBase/health')).catchError((_) {}));

  final syncService = SyncService(db, baseUrl: apiBase);
  syncService.start();

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        syncServiceProvider.overrideWithValue(syncService),
      ],
      child: const SolvorTutorApp(),
    ),
  );
}

Future<void> _loadSeedDataIfNeeded(AppDatabase db) async {
  final loaded = await db.isSeedLoaded();
  if (loaded) return;

  await db.transaction(() async {
    await _loadTaxonomy(db);
    await _loadSeedQuestions(db);
  });

  await FTS5IndexBuilder(db).buildIndex();
}

Future<void> _loadTaxonomy(AppDatabase db) async {
  final jsonStr = await rootBundle.loadString('assets/seed_data/taxonomy.json');
  final List<dynamic> nodes = jsonDecode(jsonStr) as List<dynamic>;

  for (final node in nodes) {
    await db.into(db.taxonomyNodes).insert(
          TaxonomyNodesCompanion.insert(
            id: node['id'] as String,
            name: node['name'] as String,
            parentId: Value<String?>(node['parent_id'] as String?),
            level: node['level'] as int,
          ),
        );
  }
}

Future<void> _loadSeedQuestions(AppDatabase db) async {
  final jsonStr =
      await rootBundle.loadString('assets/seed_data/seed_questions.json');
  final List<dynamic> questions = jsonDecode(jsonStr) as List<dynamic>;

  for (final q in questions) {
    final optsEn = (q['options_en'] as List<dynamic>)
        .map((e) => e.toString())
        .toList();
    final optsHi = (q['options_hi'] as List<dynamic>)
        .map((e) => e.toString())
        .toList();

    final shortcutFormulaNote = q['shortcut_formula_note'] as String?;
    final commonMistakeNote = q['common_mistake_note'] as String?;

    await db.into(db.questions).insert(
          QuestionsCompanion.insert(
            id: q['id'] as String,
            taxonomyId: q['taxonomy_id'] as String,
            questionEn: q['question_en'] as String,
            questionHi: q['question_hi'] as String,
            optionsEn: jsonEncode(optsEn),
            optionsHi: jsonEncode(optsHi),
            correctOption: q['correct_option'] as int,
            difficultyLevel: q['difficulty_level'] as String,
            explanationEn: q['explanation_en'] as String,
            explanationHi: q['explanation_hi'] as String,
            explanationHinglish: q['explanation_hinglish'] as String,
            shortcutFormulaNote: shortcutFormulaNote != null
                ? Value(shortcutFormulaNote)
                : Value.absent(),
            commonMistakeNote: commonMistakeNote != null
                ? Value(commonMistakeNote)
                : Value.absent(),
            createdAt: DateTime.now(),
          ),
        );
  }
}
