import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/mascot/mascot_widget.dart';
import '../test_provider.dart';

class TestDebriefScreen extends ConsumerWidget {
  final String testId;
  const TestDebriefScreen({super.key, required this.testId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(testProvider(testId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (state.isLoading || state.session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final session = state.session!;
    final total = session.questions.length;
    final correct = session.questions
        .where((q) => session.answers[q.id] == q.correctOption)
        .length;
    final pct = total == 0 ? 0 : (correct / total * 100).round();

    final emotion = pct >= 70
        ? MascotEmotion.celebrating
        : pct >= 40
            ? MascotEmotion.happy
            : MascotEmotion.sad;

    final message = pct >= 80
        ? 'Shabash! $correct/$total sahi. Tum champion ho!'
        : pct >= 60
            ? 'Accha kiya! $correct/$total sahi. Thoda aur practice karo.'
            : pct >= 40
                ? '$correct/$total sahi. Review karo — improvement hoga!'
                : 'Koi baat nahi. $correct/$total sahi. Har galti ek lesson hai!';

    return Scaffold(
      backgroundColor: isDark ? kVoid : kPaper,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              MascotWidget(emotion: emotion, size: 120),
              const SizedBox(height: 24),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? kSurface : Colors.white,
                  border: Border(
                    left: BorderSide(
                      color: pct >= 60 ? kNeonTeal : kNeonPurple,
                      width: 3,
                    ),
                    top: BorderSide(color: isDark ? kSubtle : kBorder),
                    right: BorderSide(color: isDark ? kSubtle : kBorder),
                    bottom: BorderSide(color: isDark ? kSubtle : kBorder),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '$pct%',
                      style: TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w900,
                        color: pct >= 60
                            ? (isDark ? kNeonTeal : kInk)
                            : (isDark ? kNeonPurple : kMuted),
                      ),
                    ),
                    Text(
                      '$correct out of $total correct',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white54 : kMuted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : kInk,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              _ActionButton(
                label: 'Galat jawab review karo',
                color: isDark ? kNeonPurple : kInk,
                textColor: isDark ? Colors.black : Colors.white,
                onTap: () => context.go('/review/$testId'),
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _ActionButton(
                label: 'AI Tutor se help lo',
                color: isDark ? kSurface : Colors.white,
                textColor: isDark ? Colors.white : kInk,
                borderColor: isDark ? kSubtle : kBorder,
                onTap: () => context.push('/tutor-chat'),
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _ActionButton(
                label: 'Ghar wapas jao',
                color: isDark ? kSurface : Colors.white,
                textColor: isDark ? Colors.white54 : kMuted,
                borderColor: isDark ? kSubtle : kBorder,
                onTap: () => context.go('/home'),
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final Color? borderColor;
  final bool isDark;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
    required this.isDark,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          border: borderColor != null ? Border.all(color: borderColor!) : null,
        ),
        child: Text(
          label.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
