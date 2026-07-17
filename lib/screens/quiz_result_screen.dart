import 'package:flutter/material.dart';
import 'package:kelimo/services/interstitial_ad_service.dart';

int calculateQuizPercentage({required int correct, required int total}) {
  if (total <= 0) return 0;
  return ((correct / total) * 100).round();
}

int quizStarCount({required int correct, required int total}) {
  final percentage = calculateQuizPercentage(correct: correct, total: total);

  if (percentage == 100) return 5;
  if (percentage >= 90) return 4;
  if (percentage >= 70) return 3;
  if (percentage >= 50) return 2;
  if (percentage > 0) return 1;
  return 0;
}

String quizMotivation(int percentage) {
  if (percentage == 100) return 'Mükemmel!';
  if (percentage >= 80) return 'Harika gidiyorsun!';
  if (percentage >= 60) return 'Güzel iş!';
  if (percentage >= 40) {
    return 'Biraz daha çalışırsan çok daha iyi olacak.';
  }
  return 'Pes etme, tekrar deneyelim!';
}

String formatQuizDuration(Duration duration) {
  final totalSeconds = duration.isNegative ? 0 : duration.inSeconds;
  if (totalSeconds < 60) return '$totalSeconds sn';

  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes dk $seconds sn';
}

class QuizResultScreen extends StatefulWidget {
  QuizResultScreen({
    super.key,
    required this.categoryName,
    required this.correctAnswerCount,
    required this.totalQuestionCount,
    required this.successPercentage,
    required this.xpAwarded,
    required this.longestCorrectStreak,
    required this.elapsedDuration,
    required this.onRetry,
    required this.onReturnToCategory,
    required this.onReturnHome,
    this.interstitialAdService,
  }) : assert(totalQuestionCount > 0),
       assert(correctAnswerCount >= 0),
       assert(correctAnswerCount <= totalQuestionCount),
       assert(successPercentage >= 0 && successPercentage <= 100),
       assert(xpAwarded >= 0),
       assert(longestCorrectStreak >= 0),
       assert(longestCorrectStreak <= correctAnswerCount),
       assert(!elapsedDuration.isNegative);

  final String categoryName;
  final int correctAnswerCount;
  final int totalQuestionCount;
  final int successPercentage;
  final int xpAwarded;
  final int longestCorrectStreak;
  final Duration elapsedDuration;
  final VoidCallback onRetry;
  final VoidCallback onReturnToCategory;
  final VoidCallback onReturnHome;
  final InterstitialAdService? interstitialAdService;

  @override
  State<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends State<QuizResultScreen> {
  bool _isLeaving = false;

  Future<void> _leave(VoidCallback navigate) async {
    if (_isLeaving) return;
    final adService = widget.interstitialAdService;
    if (adService == null) {
      navigate();
      return;
    }
    setState(() => _isLeaving = true);
    try {
      await adService.showIfEligible();
    } catch (_) {
      // Reklam hatası kullanıcının seçtiği navigasyonu engellememeli.
    }
    if (mounted) navigate();
  }

  @override
  Widget build(BuildContext context) {
    final starCount = quizStarCount(
      correct: widget.correctAnswerCount,
      total: widget.totalQuestionCount,
    );
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '🎉',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 64),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tebrikler!',
                      textAlign: TextAlign.center,
                      style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${widget.categoryName} Quizi Tamamlandı',
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: 24),
                    _ScoreCard(
                      correctAnswerCount: widget.correctAnswerCount,
                      totalQuestionCount: widget.totalQuestionCount,
                      percentage: widget.successPercentage,
                      starCount: starCount,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      quizMotivation(widget.successPercentage),
                      textAlign: TextAlign.center,
                      style: textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.xpAwarded > 0) ...[
                      const SizedBox(height: 12),
                      Text(
                        '🏆 Kusursuz sonuç! +25 XP kazandın.',
                        textAlign: TextAlign.center,
                        style: textTheme.titleMedium?.copyWith(
                          color: Colors.amber.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    _SummaryCards(
                      xpAwarded: widget.xpAwarded,
                      longestCorrectStreak: widget.longestCorrectStreak,
                      elapsedDuration: widget.elapsedDuration,
                    ),
                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed: _isLeaving ? null : widget.onRetry,
                      child: const Text('Tekrar Çöz'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _isLeaving
                          ? null
                          : () => _leave(widget.onReturnToCategory),
                      child: const Text('Kategoriye Dön'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _isLeaving
                          ? null
                          : () => _leave(widget.onReturnHome),
                      child: const Text('Ana Sayfa'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.correctAnswerCount,
    required this.totalQuestionCount,
    required this.percentage,
    required this.starCount,
  });

  final int correctAnswerCount;
  final int totalQuestionCount;
  final int percentage;
  final int starCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final emptyStarColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.grey.shade600
        : Colors.grey.shade300;

    return Card(
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(
          children: [
            Text(
              '$correctAnswerCount / $totalQuestionCount',
              style: textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '%$percentage başarı',
              style: textTheme.titleLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < 5; index++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(
                      index < starCount
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: index < starCount
                          ? Colors.amber.shade700
                          : emptyStarColor,
                      size: 36,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({
    required this.xpAwarded,
    required this.longestCorrectStreak,
    required this.elapsedDuration,
  });

  final int xpAwarded;
  final int longestCorrectStreak;
  final Duration elapsedDuration;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _SummaryCard(
        icon: Icons.local_fire_department_rounded,
        label: 'Seri',
        value: '$longestCorrectStreak doğru',
      ),
      _SummaryCard(
        icon: Icons.timer_outlined,
        label: 'Süre',
        value: formatQuizDuration(elapsedDuration),
      ),
      _SummaryCard(
        icon: Icons.bolt_rounded,
        label: 'XP',
        value: xpAwarded > 0 ? '+$xpAwarded XP' : '0 XP',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 520) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 12),
              Expanded(child: cards[1]),
              const SizedBox(width: 12),
              Expanded(child: cards[2]),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            cards[0],
            const SizedBox(height: 12),
            cards[1],
            const SizedBox(height: 12),
            cards[2],
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: colorScheme.primary),
            const SizedBox(height: 8),
            Text(label, style: textTheme.labelLarge),
            const SizedBox(height: 2),
            Text(
              value,
              textAlign: TextAlign.center,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
