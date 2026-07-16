import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kelimo/data/achievement_catalog.dart';
import 'package:kelimo/models/progress_statistics.dart';
import 'package:kelimo/models/quiz_attempt.dart';
import 'package:kelimo/screens/achievements_screen.dart';
import 'package:kelimo/services/achievement_service.dart';
import 'package:kelimo/services/statistics_service.dart';
import 'package:kelimo/theme/app_theme.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({
    required this.statisticsService,
    super.key,
    this.achievementService,
  });

  final StatisticsService statisticsService;
  final AchievementService? achievementService;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.statisticsService.refresh());
    final achievementService = widget.achievementService;
    if (achievementService != null) {
      unawaited(_refreshAchievements(achievementService));
    }
  }

  Future<void> _refreshAchievements(AchievementService service) async {
    try {
      await service.evaluate();
    } catch (_) {
      // İstatistik ekranı başarım verisi geçici olarak okunamasa da açılmalı.
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: AnimatedBuilder(
        animation: widget.statisticsService,
        builder: (context, child) {
          final service = widget.statisticsService;
          final statistics = service.statistics;

          if (service.isLoading && statistics == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (statistics == null) {
            return _ErrorState(onRetry: service.refresh);
          }

          return RefreshIndicator(
            onRefresh: service.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'İlerleme',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        const Text('Tüm çalışmalarının güncel özeti'),
                        const SizedBox(height: 24),
                        _OverviewGrid(statistics: statistics),
                        if (widget.achievementService case final service?) ...[
                          const SizedBox(height: 16),
                          _AchievementsLinkCard(
                            service: service,
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      AchievementsScreen(service: service),
                                ),
                              );
                              if (mounted) {
                                unawaited(_refreshAchievements(service));
                              }
                            },
                          ),
                        ],
                        const SizedBox(height: 16),
                        _WordDistributionCard(
                          distribution: statistics.distribution,
                        ),
                        const SizedBox(height: 16),
                        _QuizStatisticsCard(statistics: statistics),
                        if (statistics.recentAttempts.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text(
                            'Son quizler',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          for (final attempt in statistics.recentAttempts) ...[
                            _RecentQuizCard(attempt: attempt),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AchievementsLinkCard extends StatelessWidget {
  const _AchievementsLinkCard({required this.service, required this.onTap});

  final AchievementService service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final total = AchievementCatalog.achievements.length;
    return AnimatedBuilder(
      animation: service,
      builder: (context, child) {
        final unlocked = service.unlockedCount;
        return Card(
          key: const ValueKey('progress-achievements-card'),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: AppDimensions.cardPadding,
              child: Row(
                children: [
                  Icon(
                    Icons.workspace_premium_rounded,
                    size: 36,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Başarımlar',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text('$unlocked / $total rozet'),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: total == 0 ? 0 : unlocked / total,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OverviewGrid extends StatelessWidget {
  const _OverviewGrid({required this.statistics});

  final GeneralProgressStatistics statistics;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Seviye', '${statistics.currentLevel}', Icons.workspace_premium_rounded),
      ('Toplam XP', '${statistics.totalXp}', Icons.bolt_rounded),
      (
        'Güncel seri',
        '${statistics.currentStreak} gün',
        Icons.local_fire_department_rounded,
      ),
      (
        'Bugünkü değerlendirme',
        '${statistics.todayReviewCount}',
        Icons.today_rounded,
      ),
      (
        'Başlanan kelime',
        '${statistics.startedWordCount}',
        Icons.school_rounded,
      ),
      (
        'Favori kelime',
        '${statistics.favoriteWordCount}',
        Icons.favorite_rounded,
      ),
      (
        'Tamamlanan quiz',
        '${statistics.quizStatistics.totalQuizCount}',
        Icons.quiz_rounded,
      ),
      (
        'Quiz başarısı',
        '%${statistics.quizStatistics.generalSuccessPercentage}',
        Icons.insights_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 380 ? 1 : 2;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: _MetricCard(
                  label: item.$1,
                  value: item.$2,
                  icon: item.$3,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WordDistributionCard extends StatelessWidget {
  const _WordDistributionCard({required this.distribution});

  final WordLearningDistribution distribution;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppDimensions.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kelime öğrenme dağılımı',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 18),
            _DistributionRow(
              label: 'Yeni',
              count: distribution.newCount,
              ratio: distribution.ratioFor(distribution.newCount),
            ),
            const SizedBox(height: 14),
            _DistributionRow(
              label: 'Öğreniliyor',
              count: distribution.learningCount,
              ratio: distribution.ratioFor(distribution.learningCount),
            ),
            const SizedBox(height: 14),
            _DistributionRow(
              label: 'Öğrenildi',
              count: distribution.learnedCount,
              ratio: distribution.ratioFor(distribution.learnedCount),
            ),
          ],
        ),
      ),
    );
  }
}

class _DistributionRow extends StatelessWidget {
  const _DistributionRow({
    required this.label,
    required this.count,
    required this.ratio,
  });

  final String label;
  final int count;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final percentage = (ratio * 100).round();
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text('$count • %$percentage'),
          ],
        ),
        const SizedBox(height: 7),
        LinearProgressIndicator(value: ratio.clamp(0.0, 1.0)),
      ],
    );
  }
}

class _QuizStatisticsCard extends StatelessWidget {
  const _QuizStatisticsCard({required this.statistics});

  final GeneralProgressStatistics statistics;

  @override
  Widget build(BuildContext context) {
    final quiz = statistics.quizStatistics;
    return Card(
      child: Padding(
        padding: AppDimensions.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quiz istatistikleri',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (quiz.totalQuizCount == 0)
              const Text('Henüz tamamlanmış bir quiz yok.')
            else ...[
              _ValueLine(label: 'Toplam quiz', value: '${quiz.totalQuizCount}'),
              _ValueLine(
                label: 'Doğru / soru',
                value: '${quiz.totalCorrectCount} / ${quiz.totalQuestionCount}',
              ),
              _ValueLine(
                label: 'Genel başarı',
                value: '%${quiz.generalSuccessPercentage}',
              ),
              _ValueLine(
                label: 'En iyi kategori',
                value: statistics.bestCategoryName ?? '—',
              ),
              _ValueLine(
                label: 'En yüksek skor',
                value: '%${statistics.highestQuizScore}',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ValueLine extends StatelessWidget {
  const _ValueLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _RecentQuizCard extends StatelessWidget {
  const _RecentQuizCard({required this.attempt});

  final QuizAttempt attempt;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    categoryNameForId(attempt.categoryId),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${attempt.correctCount} / ${attempt.totalQuestions} • '
                    '%${attempt.scorePercent} • '
                    '${attempt.xpAwarded > 0 ? '+' : ''}'
                    '${attempt.xpAwarded} XP',
                  ),
                  const SizedBox(height: 3),
                  Text(
                    formatTurkishDate(attempt.completedAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 40),
            const SizedBox(height: 12),
            const Text('İstatistikler yüklenemedi.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Tekrar Dene')),
          ],
        ),
      ),
    );
  }
}
