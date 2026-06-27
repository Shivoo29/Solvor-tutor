import 'package:drift/drift.dart';

import '../app_database.dart';

part 'questions_dao.g.dart';

@DriftAccessor(tables: [Questions, TaxonomyNodes])
class QuestionsDao extends DatabaseAccessor<AppDatabase>
    with _$QuestionsDaoMixin {
  QuestionsDao(super.db);

  Future<List<Question>> getAllQuestions() => select(questions).get();

  Future<Question?> getQuestionById(String id) async {
    final results = await (select(questions)..where((t) => t.id.equals(id)))
        .get();
    return results.isEmpty ? null : results.first;
  }

  Future<TaxonomyNode?> getTaxonomyNode(String id) async {
    final results =
        await (select(taxonomyNodes)..where((t) => t.id.equals(id))).get();
    return results.isEmpty ? null : results.first;
  }

  Future<List<Question>> getQuestionsByTaxonomy(String taxonomyId) async {
    return (select(questions)
          ..where((t) => t.taxonomyId.equals(taxonomyId)))
        .get();
  }

  Future<List<Question>> getQuestionsBySubject(String subjectId) async {
    final subTopicIds = await (select(taxonomyNodes)
          ..where((t) => t.parentId.equals(subjectId)))
        .get();
    final topicIds = <String>[];
    for (final topic in subTopicIds) {
      topicIds.add(topic.id);
    }
    if (topicIds.isEmpty) return [];

    final subSubTopicIds = await (select(taxonomyNodes)
          ..where((t) => t.parentId.isIn(topicIds)))
        .get();
    final allChildIds = <String>[...topicIds];
    for (final sub in subSubTopicIds) {
      allChildIds.add(sub.id);
    }

    return (select(questions)
          ..where((t) => t.taxonomyId.isIn(allChildIds)))
        .get();
  }

  Future<List<Question>> getRandomQuestionsBySubject(
    String subjectId,
    int count,
  ) async {
    final result = await getQuestionsBySubject(subjectId);
    result.shuffle();
    if (result.length > count) {
      return result.sublist(0, count);
    }
    return result;
  }

  Future<void> bulkInsertQuestions(List<QuestionsCompanion> entries) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(questions, entries);
    });
  }

  Future<void> insertQuestion(QuestionsCompanion question) async {
    await into(questions).insert(question);
  }

  Future<int> countQuestions() async {
    final result = await select(questions).get();
    return result.length;
  }

  Future<List<Question>> searchByKeyword(String keyword, {String language = 'en', int limit = 3}) async {
    final lower = keyword.toLowerCase();
    return (select(questions)
      ..where((q) => q.questionEn.like('%$lower%') | q.taxonomyId.like('%$lower%'))
      ..limit(limit))
    .get();
  }
}
