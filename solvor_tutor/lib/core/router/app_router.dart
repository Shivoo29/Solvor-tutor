import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../modules/home/presentation/home_screen.dart';
import '../../modules/onboarding/presentation/onboarding_screen.dart';
import '../../modules/diagnostic/presentation/diagnostic_start_screen.dart';
import '../../modules/test_engine/presentation/screens/test_screen.dart';
import '../../modules/test_engine/presentation/screens/test_debrief_screen.dart';
import '../../modules/review/presentation/screens/review_screen.dart';
import '../../modules/error_notebook/presentation/screens/error_notebook_screen.dart';
import '../../modules/error_notebook/presentation/screens/flashcard_screen.dart';
import '../../modules/ai_tutor/presentation/screens/ai_tutor_screen.dart';
import '../../modules/ai_tutor/presentation/screens/tutor_chat_screen.dart';
import '../../modules/lesson/presentation/screens/lesson_screen.dart';
import '../../modules/settings/settings_screen.dart';
import '../auth/auth_state.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/onboarding',
    redirect: (context, state) {
      if (authState.isLoading) return null;

      final isOnOnboarding = state.matchedLocation == '/onboarding';
      final isProtected = !isOnOnboarding;

      if (authState.isLoggedIn && isOnOnboarding) return '/home';
      if (!authState.isLoggedIn && isProtected) return '/onboarding';
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/diagnostic',
        name: 'diagnostic',
        builder: (context, state) => const DiagnosticStartScreen(),
      ),
      GoRoute(
        path: '/test/:testId',
        name: 'test',
        builder: (context, state) {
          final testId = state.pathParameters['testId'] ?? '';
          return TestScreen(testId: testId);
        },
      ),
      GoRoute(
        path: '/debrief/:testId',
        name: 'debrief',
        builder: (context, state) {
          final testId = state.pathParameters['testId'] ?? '';
          return TestDebriefScreen(testId: testId);
        },
      ),
      GoRoute(
        path: '/review/:testId',
        name: 'review',
        builder: (context, state) {
          final testId = state.pathParameters['testId'] ?? '';
          return ReviewScreen(testId: testId);
        },
      ),
      GoRoute(
        path: '/error-notebook',
        name: 'error-notebook',
        builder: (context, state) => const ErrorNotebookScreen(),
        routes: [
          GoRoute(
            path: 'flashcard',
            name: 'flashcard',
            builder: (context, state) => const FlashcardScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/ai-tutor',
        name: 'ai-tutor',
        builder: (context, state) => const AiTutorScreen(),
      ),
      GoRoute(
        path: '/tutor-chat',
        name: 'tutor-chat',
        builder: (context, state) => const TutorChatScreen(),
      ),
      GoRoute(
        path: '/lesson/:topic',
        name: 'lesson',
        builder: (context, state) {
          final topic = state.pathParameters['topic'] ?? 'General Studies';
          return LessonScreen(topic: topic);
        },
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
