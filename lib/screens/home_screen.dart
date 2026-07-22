import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kelimo/data/category_catalog.dart';
import 'package:kelimo/models/category_hub_snapshot.dart';
import 'package:kelimo/models/learning_category.dart';
import 'package:kelimo/models/progress_statistics.dart';
import 'package:kelimo/repositories/quiz_repository.dart';
import 'package:kelimo/repositories/word_progress_repository.dart';
import 'package:kelimo/screens/category_screen.dart';
import 'package:kelimo/screens/category_selection_screen.dart';
import 'package:kelimo/screens/learning_center_screen.dart';
import 'package:kelimo/screens/progress_screen.dart';
import 'package:kelimo/screens/settings_screen.dart';
import 'package:kelimo/services/data_management_service.dart';
import 'package:kelimo/services/achievement_service.dart';
import 'package:kelimo/services/app_navigation_controller.dart';
import 'package:kelimo/services/category_hub_service.dart';
import 'package:kelimo/services/daily_reminder_service.dart';
import 'package:kelimo/services/learning_center_service.dart';
import 'package:kelimo/services/statistics_service.dart';
import 'package:kelimo/services/streak_service.dart';
import 'package:kelimo/services/settings_service.dart';
import 'package:kelimo/services/xp_service.dart';
import 'package:kelimo/services/interstitial_ad_service.dart';
import 'package:kelimo/services/category_access_service.dart';
import 'package:kelimo/theme/app_theme.dart';
import 'package:kelimo/widgets/glass_surface.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.streakService,
    required this.wordProgressStore,
    required this.xpService,
    required this.quizStore,
    required this.statisticsService,
    required this.settingsService,
    required this.dataManagementService,
    this.achievementService,
    this.learningCenterService,
    this.dailyReminderService,
    this.navigationController,
    this.interstitialAdService,
    this.categoryAccessService,
    super.key,
  });

  final StreakService streakService;
  final WordProgressStore wordProgressStore;
  final XpService xpService;
  final QuizStore quizStore;
  final StatisticsService statisticsService;
  final SettingsService settingsService;
  final DataManagementService dataManagementService;
  final AchievementService? achievementService;
  final LearningCenterService? learningCenterService;
  final DailyReminderService? dailyReminderService;
  final AppNavigationController? navigationController;
  final InterstitialAdService? interstitialAdService;
  final CategoryAccessService? categoryAccessService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late Future<CategoryHubSnapshot> _categorySnapshot;
  late final CategoryHubService _categoryHubService;
  late final LearningCenterService _learningCenterService;

  @override
  void initState() {
    super.initState();
    _learningCenterService =
        widget.learningCenterService ??
        LearningCenterService(wordProgressStore: widget.wordProgressStore);
    _categoryHubService = CategoryHubService(
      wordProgressStore: widget.wordProgressStore,
      quizStore: widget.quizStore,
      statisticsService: widget.statisticsService,
    );
    widget.dataManagementService.addListener(_handleDataReset);
    widget.navigationController?.addListener(_handleNavigationRequest);
    _handleNavigationRequest();
    unawaited(widget.statisticsService.refresh());
    _categorySnapshot = _categoryHubService.load();
  }

  void _handleDataReset() {
    if (mounted) _reloadCategoryProgress();
  }

  void _handleNavigationRequest() {
    if (widget.navigationController?.consumeDailyReviewRequest() != true) {
      return;
    }
    if (mounted) setState(() => _selectedIndex = 1);
  }

  @override
  void dispose() {
    widget.dataManagementService.removeListener(_handleDataReset);
    widget.navigationController?.removeListener(_handleNavigationRequest);
    super.dispose();
  }

  void _reloadCategoryProgress() {
    unawaited(widget.statisticsService.refresh());
    setState(() {
      _categorySnapshot = _categoryHubService.load();
    });
  }

  Future<void> _openCategory(LearningCategory category) async {
    final access = widget.categoryAccessService;
    if (access != null && !access.canOpen(category)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bu kategori henüz kilitli.')),
        );
      }
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CategoryScreen(
          category: category,
          streakService: widget.streakService,
          wordProgressStore: widget.wordProgressStore,
          xpService: widget.xpService,
          quizStore: widget.quizStore,
          statisticsService: widget.statisticsService,
          settingsService: widget.settingsService,
          achievementService: widget.achievementService,
          dailyReminderService: widget.dailyReminderService,
          interstitialAdService: widget.interstitialAdService,
          categoryAccessService: widget.categoryAccessService,
        ),
      ),
    );
    if (mounted) _reloadCategoryProgress();
  }

  Future<void> _showCategorySelection(CategoryHubSnapshot snapshot) async {
    final category = await Navigator.of(context).push<LearningCategory>(
      MaterialPageRoute(
        builder: (_) => CategorySelectionScreen(
          snapshot: snapshot,
          categoryAccessService: widget.categoryAccessService,
        ),
      ),
    );
    if (category != null && mounted) await _openCategory(category);
  }

  @override
  Widget build(BuildContext context) {
    final streakService = widget.streakService;
    final wordProgressStore = widget.wordProgressStore;
    final xpService = widget.xpService;

    return Scaffold(
      body: switch (_selectedIndex) {
        1 => LearningCenterScreen(
          service: _learningCenterService,
          wordProgressStore: wordProgressStore,
          streakService: streakService,
          xpService: xpService,
          settingsService: widget.settingsService,
          achievementService: widget.achievementService,
          dailyReminderService: widget.dailyReminderService,
          categoryAccessService: widget.categoryAccessService,
        ),
        2 => ProgressScreen(
          statisticsService: widget.statisticsService,
          achievementService: widget.achievementService,
          wordProgressStore: widget.wordProgressStore,
        ),
        3 => SettingsScreen(
          settingsService: widget.settingsService,
          dataManagementService: widget.dataManagementService,
          dailyReminderService: widget.dailyReminderService,
          interstitialAdService: widget.interstitialAdService,
        ),
        _ => GlassBackground(
          child: SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 960),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _Greeting(),
                            const SizedBox(height: 20),
                            FutureBuilder<CategoryHubSnapshot>(
                              future: _categorySnapshot,
                              builder: (context, snapshot) {
                                final data = snapshot.data;
                                if (data == null &&
                                    snapshot.connectionState !=
                                        ConnectionState.done) {
                                  return const _CategoryHubLoadingCard();
                                }
                                final safeData =
                                    data ??
                                    const CategoryHubSnapshot(
                                      progressByCategoryId: {},
                                      recentCategories: [],
                                    );
                                return _HomeCategoryHub(
                                  snapshot: safeData,
                                  categoryAccessService:
                                      widget.categoryAccessService,
                                  onContinue: (category) {
                                    if (category == null) {
                                      _showCategorySelection(safeData);
                                    } else {
                                      _openCategory(category);
                                    }
                                  },
                                  onShowAll: () =>
                                      _showCategorySelection(safeData),
                                );
                              },
                            ),
                            const SizedBox(height: 20),
                            _ProgressCards(
                              streakService: streakService,
                              xpService: xpService,
                              statisticsService: widget.statisticsService,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      },
      bottomNavigationBar: _GlassBottomNavigation(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          if (index >= 0 && index <= 3) {
            setState(() => _selectedIndex = index);
          }
        },
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
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
      ],
    );
  }
}

class _ProgressCards extends StatelessWidget {
  const _ProgressCards({
    required this.streakService,
    required this.xpService,
    required this.statisticsService,
  });

  final StreakService streakService;
  final XpService xpService;
  final StatisticsService statisticsService;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        streakService,
        xpService,
        statisticsService,
      ]),
      builder: (context, child) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

    return _GlassCard(
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
              key: const ValueKey('level-progress'),
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

    return _GlassCard(
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

    return _GlassCard(
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
            LinearProgressIndicator(
              key: const ValueKey('daily-task-progress'),
              value: displayedCount / dailyGoal,
            ),
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
  if (distribution.learnedCount > 0) {
    return 'Harika, ${distribution.learnedCount} kelimede ilerleme kaydettin!';
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
      return _GlassCard(
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

    return _GlassCard(
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
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${distribution.learnedCount} / '
                      '${distribution.totalCount} kelime',
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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

class _HomeCategoryHub extends StatelessWidget {
  const _HomeCategoryHub({
    required this.snapshot,
    required this.onContinue,
    required this.onShowAll,
    this.categoryAccessService,
  });

  final CategoryHubSnapshot snapshot;
  final ValueChanged<LearningCategory?> onContinue;
  final VoidCallback onShowAll;
  final CategoryAccessService? categoryAccessService;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final candidate = snapshot.lastCategory;
    final category =
        candidate != null && (categoryAccessService?.canOpen(candidate) ?? true)
        ? candidate
        : null;
    final statistics = category == null
        ? null
        : snapshot.progressFor(category.id);
    final total = statistics?.totalWordCount ?? category?.words.length ?? 0;
    final learned = statistics?.learnedWordCount ?? 0;
    final progress = total == 0 ? 0.0 : learned / total;
    final percentage = (progress * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Kaldığın yerden devam et',
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GlassSurface(
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
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          category?.emoji ?? '📚',
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category?.title ?? 'İlk kategorini seç',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              category == null
                                  ? 'Öğrenmeye başlamak için bir kategori seç'
                                  : '$learned / $total kelime',
                            ),
                          ],
                        ),
                      ),
                      if (category != null)
                        Text(
                          '%$percentage',
                          style: textTheme.labelLarge?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  if (category != null) ...[
                    const SizedBox(height: 16),
                    LinearProgressIndicator(value: progress, minHeight: 7),
                  ],
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () => onContinue(category),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Devam Et'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        GlassSurface(
          key: const ValueKey('all-categories-button'),
          enableBlur: true,
          borderRadius: BorderRadius.circular(18),
          child: Semantics(
            button: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onShowAll,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 54),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Tüm Kategorileri Gör · '
                          '${CategoryCatalog.categories.length}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_rounded),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryHubLoadingCard extends StatelessWidget {
  const _CategoryHubLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Kaldığın yerden devam et',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const _GlassCard(
          enableBlur: true,
          child: Padding(
            padding: AppDimensions.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(),
                SizedBox(height: 14),
                Text('Kategoriler yükleniyor...'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, this.enableBlur = false});

  final Widget child;
  final bool enableBlur;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      enableBlur: enableBlur,
      padding: EdgeInsets.zero,
      child: Card(
        color: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        child: child,
      ),
    );
  }
}

class _GlassBottomNavigation extends StatelessWidget {
  const _GlassBottomNavigation({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: GlassSurface(
        key: const ValueKey('glass-bottom-navigation'),
        borderRadius: BorderRadius.circular(30),
        blurSigma: 18,
        padding: EdgeInsets.zero,
        child: NavigationBar(
          height: 70,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
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
      ),
    );
  }
}
