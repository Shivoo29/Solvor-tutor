import 'package:drift/drift.dart';

import '../app_database.dart';

part 'spaced_repetition_dao.g.dart';

@DriftAccessor(tables: [SpacedRepetition])
class SpacedRepetitionDao extends DatabaseAccessor<AppDatabase>
    with _$SpacedRepetitionDaoMixin {
  SpacedRepetitionDao(super.db);

  Future<List<SpacedRepetitionData>> getDueToday(String userId) async {
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return (select(spacedRepetition)
          ..where((t) =>
              t.userId.equals(userId) &
              t.nextReviewDate.isSmallerOrEqualValue(todayStr) &
              t.mastered.equals(false)))
        .get();
  }

  Future<SpacedRepetitionData?> getEntry(String userId, String questionId) async {
    final results = await (select(spacedRepetition)
          ..where((t) =>
              t.userId.equals(userId) & t.questionId.equals(questionId)))
        .get();
    return results.isEmpty ? null : results.first;
  }

  Future<void> scheduleForReview(
    String id,
    String userId,
    String questionId,
  ) async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final tomorrowStr =
        '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';

    final existing = await getEntry(userId, questionId);
    if (existing != null) {
      await (update(spacedRepetition)
            ..where((t) => t.id.equals(existing.id)))
          .write(SpacedRepetitionCompanion(
        intervalDays: const Value(1),
        nextReviewDate: Value(tomorrowStr),
        mastered: const Value(false),
      ));
    } else {
      await into(spacedRepetition).insert(SpacedRepetitionCompanion(
        id: Value(id),
        userId: Value(userId),
        questionId: Value(questionId),
        intervalDays: const Value(1),
        nextReviewDate: Value(tomorrowStr),
        mastered: const Value(false),
        createdAt: Value(DateTime.now()),
      ));
    }
  }

  Future<void> markReviewed(String id, bool wasCorrect) async {
    final entry = await (select(spacedRepetition)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (entry == null) return;

    if (!wasCorrect) {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final tomorrowStr =
          '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';
      await (update(spacedRepetition)..where((t) => t.id.equals(id))).write(
        SpacedRepetitionCompanion(
          intervalDays: const Value(1),
          nextReviewDate: Value(tomorrowStr),
          mastered: const Value(false),
        ),
      );
      return;
    }

    final nextInterval = advanceInterval(entry.intervalDays);
    if (nextInterval == null) {
      await (update(spacedRepetition)..where((t) => t.id.equals(id))).write(
        const SpacedRepetitionCompanion(mastered: Value(true)),
      );
    } else {
      final nextDate = DateTime.now().add(Duration(days: nextInterval));
      final nextDateStr =
          '${nextDate.year}-${nextDate.month.toString().padLeft(2, '0')}-${nextDate.day.toString().padLeft(2, '0')}';
      await (update(spacedRepetition)..where((t) => t.id.equals(id))).write(
        SpacedRepetitionCompanion(
          intervalDays: Value(nextInterval),
          nextReviewDate: Value(nextDateStr),
        ),
      );
    }
  }

  int? advanceInterval(int currentDays) {
    const progression = [1, 3, 7, 14];
    final index = progression.indexOf(currentDays);
    if (index == -1 || index == progression.length - 1) return null;
    return progression[index + 1];
  }

  Future<int> getDueTodayCount(String userId) async {
    final items = await getDueToday(userId);
    return items.length;
  }
}
