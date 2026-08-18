import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kelimo/data/achievement_catalog.dart';
import 'package:kelimo/models/achievement.dart';
import 'package:kelimo/models/progress_statistics.dart';
import 'package:kelimo/models/quiz_attempt.dart';
import 'package:kelimo/screens/achievements_screen.dart';
import 'package:kelimo/services/achievement_service.dart';
import 'package:kelimo/services/statistics_service.dart';
import 'package:kelimo/theme/app_theme.dart';
import 'package:kelimo/widgets/glass_surface.dart';
import 'package:kelimo/repositories/word_progress_repository.dart';
import 'package:kelimo/screens/mosaic_screen.dart';
import 'package:kelimo/services/mosaic_service.dart';
import 'package:kelimo/models/mosaic_progress.dart';

enum ProgressMilestoneKind { achievement, mosaic, completed }

class ProgressMilestone {
  const ProgressMilestone._({
    required this.kind,
    this.achievement,
    this.current = 0,
    this.target = 0,
  });

  const ProgressMilestone.achievement({
    required Achievement achievement,
    required int current,
    required int target,
  }) : this._(
         kind: ProgressMilestoneKind.achievement,
         achievement: achievement,
         current: current,
         target: target,
       );

  const ProgressMilestone.mosaic({required int current, required int target})
    : this._(
        kind: ProgressMilestoneKind.mosaic,
        current: current,
        target: target,
      );

  const ProgressMilestone.completed()
    : this._(kind: ProgressMilestoneKind.completed);

  final ProgressMilestoneKind kind;
  final Achievement? achievement;
  final int current;
  final int target;

  double get progress =>
      target <= 0 ? 0 : (current / target).clamp(0.0, 1.0).toDouble();
}

ProgressMilestone selectProgressMilestone({
  AchievementService? achievementService,
  MosaicProgress? mosaicProgress,
}) {
  if (achievementService != null) {
    Achievement? closest;
    var closestProgress = 0.0;
    var closestCurrent = 0;
    for (final achievement in AchievementCatalog.achievements) {
      if (achievement.target <= 0 ||
          achievementService.isUnlocked(achievement.id) ||
          achievement.isMet(achievementService.metrics)) {
        continue;
      }
      final current = achievement.progress(achievementService.metrics);
      final progress = (current / achievement.target).clamp(0.0, 1.0);
      if (closest == null || progress > closestProgress) {
        closest = achievement;
        closestProgress = progress;
        closestCurrent = current;
      }
    }
    if (closest != null) {
      return ProgressMilestone.achievement(
        achievement: closest,
        current: closestCurrent,
        target: closest.target,
      );
    }
  }

  if (mosaicProgress != null && !mosaicProgress.isComplete) {
    return ProgressMilestone.mosaic(
      current: mosaicProgress.discoveredCount,
      target: mosaicProgress.totalCells,
    );
  }
  return const ProgressMilestone.completed();
}

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({
    required this.statisticsService,
    super.key,
    this.achievementService,
    this.wordProgressStore,
  });

  final StatisticsService statisticsService;
  final AchievementService? achievementService;
  final WordProgressStore? wordProgressStore;

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
    final navigationClearance = 70 + MediaQuery.paddingOf(context).bottom + 24;
    return GlassBackground(
      child: SafeArea(
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
                padding: EdgeInsets.fromLTRB(20, 28, 20, navigationClearance),
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
                          _MilestoneCard(
                            achievementService: widget.achievementService,
                            mosaicService: widget.wordProgressStore == null
                                ? null
                                : MosaicService(
                                    wordProgressStore:
                                        widget.wordProgressStore!,
                                  ),
                          ),
                          const SizedBox(height: 16),
                          _OverviewGrid(statistics: statistics),
                          if (widget.achievementService
                              case final service?) ...[
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
                          if (widget.wordProgressStore case final store?) ...[
                            const SizedBox(height: 16),
                            _MosaicLinkCard(
                              service: MosaicService(wordProgressStore: store),
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
                            for (final attempt
                                in statistics.recentAttempts) ...[
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
      ),
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard({this.achievementService, this.mosaicService});

  final AchievementService? achievementService;
  final MosaicService? mosaicService;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: achievementService ?? const _SilentListenable(),
      builder: (context, child) {
        final milestone = selectProgressMilestone(
          achievementService: achievementService,
          mosaicProgress: mosaicService?.load(),
        );
        final colorScheme = Theme.of(context).colorScheme;
        final (title, detail, cta, icon, onPressed) = switch (milestone.kind) {
          ProgressMilestoneKind.achievement => (
            'Sıradaki rozet: ${milestone.achievement!.title}',
            '${milestone.current} / ${milestone.target}',
            'Başarımları Gör',
            Icons.workspace_premium_rounded,
            () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    AchievementsScreen(service: achievementService!),
              ),
            ),
          ),
          ProgressMilestoneKind.mosaic => (
            'Gizli Mozaik',
            '${milestone.current} / ${milestone.target} parça',
            'Mozaiği Gör',
            Icons.auto_awesome_rounded,
            () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MosaicScreen(service: mosaicService!),
              ),
            ),
          ),
          ProgressMilestoneKind.completed => (
            'Tüm büyük hedefleri tamamladın!',
            'Harika bir ilerleme kaydettin.',
            null,
            Icons.celebration_rounded,
            null,
          ),
        };
        return GlassSurface(
          key: const ValueKey('next-milestone-card'),
          enableBlur: true,
          padding: EdgeInsets.zero,
          child: Card(
            color: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            child: Padding(
              padding: AppDimensions.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: colorScheme.primary, size: 30),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(detail),
                  if (milestone.kind != ProgressMilestoneKind.completed) ...[
                    const SizedBox(height: 10),
                    LinearProgressIndicator(value: milestone.progress),
                  ],
                  if (cta != null) ...[
                    const SizedBox(height: 8),
                    TextButton(onPressed: onPressed, child: Text(cta)),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SilentListenable implements Listenable {
  const _SilentListenable();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

class _MosaicLinkCard extends StatelessWidget {
  const _MosaicLinkCard({required this.service});

  final MosaicService service;

  @override
  Widget build(BuildContext context) {
    final progress = service.load();
    return GlassSurface(
      key: const ValueKey('hidden-mosaic-card'),
      enableBlur: false,
      padding: EdgeInsets.zero,
      child: Card(
        color: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => MosaicScreen(service: service),
            ),
          ),
          child: Padding(
            padding: AppDimensions.cardPadding,
            child: Row(
              children: [
                const Text('🖼️', style: TextStyle(fontSize: 34)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gizli Mozaik',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text('${progress.discoveredCount} / 1080 parça'),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: progress.progress),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
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
        return GlassSurface(
          key: const ValueKey('progress-achievements-card'),
          enableBlur: false,
          padding: EdgeInsets.zero,
          child: Card(
            color: Colors.transparent,
            surfaceTintColor: Colors.transparent,
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

    final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 330 || textScale > 1.25 ? 1 : 2;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                height: columns == 2 ? 96 : null,
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
    return GlassSurface(
      enableBlur: false,
      showShadow: false,
      padding: EdgeInsets.zero,
      child: Card(
        color: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, size: 22, color: colorScheme.primary),
              const SizedBox(width: 8),
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
      ),
    );
  }
}

class _WordDistributionCard extends StatelessWidget {
  const _WordDistributionCard({required this.distribution});

  final WordLearningDistribution distribution;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      enableBlur: false,
      padding: EdgeInsets.zero,
      child: Card(
        color: Colors.transparent,
        surfaceTintColor: Colors.transparent,
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
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 14),
              _DistributionRow(
                label: 'Öğreniliyor',
                count: distribution.learningCount,
                ratio: distribution.ratioFor(distribution.learningCount),
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(height: 14),
              _DistributionRow(
                label: 'Öğrenildi',
                count: distribution.learnedCount,
                ratio: distribution.ratioFor(distribution.learnedCount),
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
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
    required this.color,
  });

  final String label;
  final int count;
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final percentage = (ratio * 100).round();
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(label)),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text('$count • %$percentage'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        LinearProgressIndicator(
          value: ratio.clamp(0.0, 1.0),
          color: color,
          backgroundColor: color.withValues(alpha: 0.14),
        ),
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
    return GlassSurface(
      enableBlur: false,
      padding: EdgeInsets.zero,
      child: Card(
        color: Colors.transparent,
        surfaceTintColor: Colors.transparent,
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
                _ValueLine(
                  label: 'Toplam quiz',
                  value: '${quiz.totalQuizCount}',
                ),
                _ValueLine(
                  label: 'Doğru / soru',
                  value:
                      '${quiz.totalCorrectCount} / ${quiz.totalQuestionCount}',
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
    final scoreColor = attempt.scorePercent >= 80
        ? Colors.green
        : attempt.scorePercent >= 50
        ? Theme.of(context).colorScheme.secondary
        : Theme.of(context).colorScheme.error;
    return GlassSurface(
      enableBlur: false,
      showShadow: false,
      padding: EdgeInsets.zero,
      child: Card(
        color: Colors.transparent,
        surfaceTintColor: Colors.transparent,
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
                      style: TextStyle(
                        color: scoreColor,
                        fontWeight: FontWeight.w600,
                      ),
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
