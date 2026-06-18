import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/questions_dao.dart';
import '../../../core/database/daos/spaced_repetition_dao.dart';
import '../../../core/database/daos/users_dao.dart';

class ReviewQueueItem {
  final String id;
  final String questionId;
  final Question question;
  final int intervalDays;
  final String nextReviewDate;
  final int daysInSystem;

  const ReviewQueueItem({
    required this.id,
    required this.questionId,
    required this.question,
    required this.intervalDays,
    required this.nextReviewDate,
    required this.daysInSystem,
  });
}

class ErrorNotebookRepository {
  final SpacedRepetitionDao _srDao;
  final QuestionsDao _questionsDao;
  final UsersDao _usersDao;
  final Uuid _uuid = const Uuid();

  ErrorNotebookRepository(this._srDao, this._questionsDao, this._usersDao);

  Future<void> triggerSchedule(String questionId) async {
    final user = await _usersDao.getUser();
    if (user == null) return;
    await _srDao.scheduleForReview(_uuid.v4(), user.id, questionId);
  }

  Future<List<ReviewQueueItem>> getReviewQueue() async {
    final user = await _usersDao.getUser();
    if (user == null) return [];
    final dueEntries = await _srDao.getDueToday(user.id);
    final List<ReviewQueueItem> items = [];
    for (final entry in dueEntries) {
      final question = await _questionsDao.getQuestionById(entry.questionId);
      if (question != null) {
        items.add(ReviewQueueItem(
          id: entry.id,
          questionId: entry.questionId,
          question: question,
          intervalDays: entry.intervalDays,
          nextReviewDate: entry.nextReviewDate,
          daysInSystem:
              DateTime.now().difference(entry.createdAt).inDays,
        ));
      }
    }
    return items;
  }

  Future<int> getDueCount() async {
    final user = await _usersDao.getUser();
    if (user == null) return 0;
    return _srDao.getDueTodayCount(user.id);
  }

  Future<void> submitReview(String id, bool wasCorrect) async {
    await _srDao.markReviewed(id, wasCorrect);
  }
}
