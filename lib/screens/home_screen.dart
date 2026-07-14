import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kelimo/data/category_catalog.dart';
import 'package:kelimo/models/learning_category.dart';
import 'package:kelimo/models/progress_statistics.dart';
import 'package:kelimo/repositories/quiz_repository.dart';
import 'package:kelimo/repositories/word_progress_repository.dart';
import 'package:kelimo/screens/category_screen.dart';
import 'package:kelimo/screens/progress_screen.dart';
import 'package:kelimo/services/statistics_service.dart';
import 'package:kelimo/services/streak_service.dart';
import 'package:kelimo/services/xp_service.dart';
import 'package:kelimo/theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.streakService,
    required this.wordProgressStore,
    required this.xpService,
    required this.quizStore,
    required this.statisticsService,
    super.key,
  });

  final StreakService streakService;
  final WordProgressStore wordProgressStore;
  final XpService xpService;
  final QuizStore quizStore;
  final StatisticsService statisticsService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late Map<String, Future<CategoryProgressStatistics>> _categoryProgress;

  @override
  void initState() {
    super.initState();
    unawaited(widget.statisticsService.refresh());
    _categoryProgress = _loadCategoryProgress();
  }

  Map<String, Future<CategoryProgressStatistics>> _loadCategoryProgress() {
    return {
      for (final category in CategoryCatalog.categories)
        if (category.isAvailable)
          category.id: widget.statisticsService.loadCategory(category.id),
    };
  }

  void _reloadCategoryProgress() {
    unawaited(widget.statisticsService.refresh());
    setState(() {
      _categoryProgress = _loadCategoryProgress();
    });
  }

  @override
  Widget build(BuildContext context) {
    final streakService = widget.streakService;
    final wordProgressStore = widget.wordProgressStore;
    final xpService = widget.xpService;
    final quizStore = widget.quizStore;

    return Scaffold(
      body: _selectedIndex == 2
          ? ProgressScreen(statisticsService: widget.statisticsService)
          : SafeArea(
              bottom: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columnCount = constraints.maxWidth >= 700 ? 2 : 1;

                  return CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                        sliver: SliverToBoxAdapter(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 960),
                              child: _HeaderAndProgress(
                                streakService: streakService,
                                xpService: xpService,
                                statisticsService: widget.statisticsService,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                        sliver: SliverToBoxAdapter(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 960),
                              child: Text(
                                'Kategoriler',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                        sliver: SliverLayoutBuilder(
                          builder: (context, constraints) {
                            final gridWidth = constraints.crossAxisExtent.clamp(
                              0.0,
                              960.0,
                            );

                            return SliverPadding(
                              padding: EdgeInsets.symmetric(
                                horizontal:
                                    (constraints.crossAxisExtent - gridWidth) /
                                    2,
                              ),
                              sliver: SliverGrid(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: columnCount,
                                      mainAxisExtent: 164,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                    ),
                                delegate: SliverChildListDelegate.fixed([
                                  for (final category
                                      in CategoryCatalog.categories)
                                    if (category.isAvailable)
                                      FutureBuilder<CategoryProgressStatistics>(
                                        future: _categoryProgress[category.id],
                                        builder: (context, snapshot) {
                                          final statistics = snapshot.data;
                                          final total =
                                              statistics?.totalWordCount ??
                                              category.words.length;
                                          final learned =
                                              statistics?.learnedWordCount ?? 0;

                                          return _CategoryCard(
                                            category: category,
                                            wordCount: total,
                                            progress: total == 0
                                                ? 0
                                                : learned / total,
                                            onTap: () async {
                                              await Navigator.of(context).push(
                                                MaterialPageRoute<void>(
                                                  builder: (_) => CategoryScreen(
                                                    category: category,
                                                    streakService:
                                                        streakService,
                                                    wordProgressStore:
                                                        wordProgressStore,
                                                    xpService: xpService,
                                                    quizStore: quizStore,
                                                    statisticsService: widget
                                                        .statisticsService,
                                                  ),
                                                ),
                                              );
                                              if (mounted) {
                                                _reloadCategoryProgress();
                                              }
                                            },
                                          );
                                        },
                                      )
                                    else
                                      _CategoryCard(
                                        category: category,
                                        wordCount: 0,
                                        progress: null,
                                      ),
                                ]),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          if (index == 0 || index == 2) {
            setState(() => _selectedIndex = index);
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Ana Sayfa',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school_rounded),
            label: 'Öğren',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'İlerleme',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Ayarlar',
          ),
        ],
      ),
    );
  }
}

class _HeaderAndProgress extends StatelessWidget {
  const _HeaderAndProgress({
    required this.streakService,
    required this.xpService,
    required this.statisticsService,
  });

  final StreakService streakService;
  final XpService xpService;
  final StatisticsService statisticsService;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AnimatedBuilder(
      animation: Listenable.merge([
        streakService,
        xpService,
        statisticsService,
      ]),
      builder: (context, child) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Merhaba!',
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text('Bugün öğrenmeye hazır mısın?', style: textTheme.titleMedium),
          const SizedBox(height: 24),
          _GeneralProgressCard(statisticsService: statisticsService),
          const SizedBox(height: 16),
          _LevelCard(xpService: xpService),
          const SizedBox(height: 16),
          _DailyOverviewCards(streakService: streakService),
        ],
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.xpService});

  final XpService xpService;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: AppDimensions.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Seviye ${xpService.currentLevel}',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text('Bir sonraki seviyeye doğru'),
                    ],
                  ),
                ),
                Text(
                  '${xpService.xpInCurrentLevel} / '
                  '${xpService.xpRequiredForNextLevel} XP',
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: xpService.progress,
              minHeight: 10,
              borderRadius: BorderRadius.circular(5),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyOverviewCards extends StatelessWidget {
  const _DailyOverviewCards({required this.streakService});

  final StreakService streakService;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;
        final cardWidth = isWide
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth,
              child: _DailyStreakCard(
                currentStreak: streakService.currentStreak,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _DailyTaskCard(
                todayCount: streakService.todayCount,
                dailyGoal: streakService.dailyGoal,
                isCompleted: streakService.isTodayCompleted,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DailyStreakCard extends StatelessWidget {
  const _DailyStreakCard({required this.currentStreak});

  final int currentStreak;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: AppDimensions.cardPadding,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.local_fire_department_rounded,
                color: colorScheme.secondary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Günlük Seri',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$currentStreak gün',
                    style: textTheme.titleLarge?.copyWith(
                      color: colorScheme.secondary,
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

class _DailyTaskCard extends StatelessWidget {
  const _DailyTaskCard({
    required this.todayCount,
    required this.dailyGoal,
    required this.isCompleted,
  });

  final int todayCount;
  final int dailyGoal;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final displayedCount = todayCount > dailyGoal ? dailyGoal : todayCount;

    return Card(
      child: Padding(
        padding: AppDimensions.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.task_alt_rounded, color: colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Günlük Görev',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '$displayedCount / $dailyGoal',
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              isCompleted
                  ? 'Günlük hedef tamamlandı'
                  : 'Bugün $dailyGoal kelime değerlendir',
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: displayedCount / dailyGoal),
          ],
        ),
      ),
    );
  }
}

String generalProgressDescription(WordLearningDistribution distribution) {
  if (distribution.totalCount == 0) return 'Henüz kelime bulunmuyor';
  if (distribution.learnedCount == distribution.totalCount) {
    return 'Tüm kelimeleri öğrendin!';
  }
  if (distribution.learningCount > 0) {
    return '${distribution.learningCount} kelime öğreniliyor';
  }
  return 'Henüz öğrenmeye başlamadın';
}

class _GeneralProgressCard extends StatelessWidget {
  const _GeneralProgressCard({required this.statisticsService});

  final StatisticsService statisticsService;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final statistics = statisticsService.statistics;

    if (statisticsService.isLoading && statistics == null) {
      return Card(
        child: Padding(
          padding: AppDimensions.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Genel ilerleme',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
              const SizedBox(height: 16),
              const Text('İlerleme yükleniyor...'),
            ],
          ),
        ),
      );
    }

    final distribution =
        statistics?.distribution ??
        const WordLearningDistribution(
          totalCount: 0,
          newCount: 0,
          learningCount: 0,
          learnedCount: 0,
        );
    final progress = distribution.ratioFor(distribution.learnedCount);

    return Card(
      child: Padding(
        padding: AppDimensions.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Genel ilerleme',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${distribution.learnedCount} / '
                  '${distribution.totalCount} kelime',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              key: const ValueKey('general-progress'),
              value: progress,
            ),
            const SizedBox(height: 16),
            Text(
              generalProgressDescription(distribution),
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.wordCount,
    required this.progress,
    this.onTap,
  });

  final LearningCategory category;
  final int wordCount;
  final double? progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final percentage = progress == null ? null : (progress! * 100).round();

    final content = Padding(
      padding: AppDimensions.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  category.emoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(progress == null ? 'Yakında' : '$wordCount kelime'),
                  ],
                ),
              ),
              if (percentage != null)
                Text(
                  '%$percentage',
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const Spacer(),
          if (progress != null) LinearProgressIndicator(value: progress),
        ],
      ),
    );

    return Card(
      clipBehavior: onTap == null ? Clip.none : Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}
