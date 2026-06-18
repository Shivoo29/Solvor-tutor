import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/questions_dao.dart';
import '../../../core/database/daos/spaced_repetition_dao.dart';
import '../../../core/database/daos/users_dao.dart';
import '../data/error_notebook_repository.dart';

final errorNotebookRepositoryProvider = Provider<ErrorNotebookRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ErrorNotebookRepository(
    SpacedRepetitionDao(db),
    QuestionsDao(db),
    UsersDao(db),
  );
});

final errorNotebookProvider =
    FutureProvider.autoDispose<List<ReviewQueueItem>>((ref) async {
  final repo = ref.watch(errorNotebookRepositoryProvider);
  return repo.getReviewQueue();
});

final errorNotebookDueCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final repo = ref.watch(errorNotebookRepositoryProvider);
  return repo.getDueCount();
});
