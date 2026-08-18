import 'package:flutter/material.dart';
import 'package:kelimo/models/category_hub_snapshot.dart';
import 'package:kelimo/models/learning_category.dart';
import 'package:kelimo/models/learning_center.dart';
import 'package:kelimo/repositories/quiz_repository.dart';
import 'package:kelimo/repositories/word_progress_repository.dart';
import 'package:kelimo/screens/category_screen.dart';
import 'package:kelimo/screens/category_selection_screen.dart';
import 'package:kelimo/screens/learning_word_list_screen.dart';
import 'package:kelimo/services/category_hub_service.dart';
import 'package:kelimo/services/learning_center_service.dart';
import 'package:kelimo/services/statistics_service.dart';
import 'package:kelimo/services/settings_service.dart';
import 'package:kelimo/services/achievement_service.dart';
import 'package:kelimo/services/daily_reminder_service.dart';
import 'package:kelimo/services/streak_service.dart';
import 'package:kelimo/services/xp_service.dart';
import 'package:kelimo/theme/app_theme.dart';
import 'package:kelimo/widgets/glass_surface.dart';
import 'package:kelimo/services/category_access_service.dart';

class LearningCenterScreen extends StatefulWidget {
  const LearningCenterScreen({
    required this.service,
    required this.wordProgressStore,
    required this.streakService,
    required this.xpService,
    required this.settingsService,
    required this.quizStore,
    required this.statisticsService,
    super.key,
    this.achievementService,
    this.dailyReminderService,
    this.categoryAccessService,
  });

  final LearningCenterService service;
  final WordProgressStore wordProgressStore;
  final StreakService streakService;
  final XpService xpService;
  final SettingsService settingsService;
  final QuizStore quizStore;
  final StatisticsService statisticsService;
  final AchievementService? achievementService;
  final DailyReminderService? dailyReminderService;
  final CategoryAccessService? categoryAccessService;

  @override
  State<LearningCenterScreen> createState() => _LearningCenterScreenState();
}

class _LearningCenterScreenState extends State<LearningCenterScreen> {
  late LearningCenterSnapshot _snapshot;
  late final CategoryHubService _categoryHubService;
  late Future<CategoryHubSnapshot> _categorySnapshot;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.service.load();
    _categoryHubService = CategoryHubService(
      wordProgressStore: widget.wordProgressStore,
      quizStore: widget.quizStore,
      statisticsService: widget.statisticsService,
    );
    _categorySnapshot = _categoryHubService.load();
  }

  void _reload() {
    setState(() {
      _snapshot = widget.service.load();
      _categorySnapshot = _categoryHubService.load();
    });
  }

  Future<void> _openCategory(LearningCategory category) async {
    final access = widget.categoryAccessService;
    if (access != null && !access.canOpen(category)) return;
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
          categoryAccessService: widget.categoryAccessService,
        ),
      ),
    );
    if (mounted) _reload();
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

  Future<void> _openFilter(LearningCenterFilter filter) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LearningWordListScreen(
          filter: filter,
          service: widget.service,
          wordProgressStore: widget.wordProgressStore,
          streakService: widget.streakService,
          xpService: widget.xpService,
          settingsService: widget.settingsService,
          achievementService: widget.achievementService,
          dailyReminderService: widget.dailyReminderService,
          categoryAccessService: widget.categoryAccessService,
        ),
      ),
    );
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final navigationClearance = 70 + MediaQuery.paddingOf(context).bottom + 24;
    return GlassBackground(
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(24, 28, 24, navigationClearance),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Öğrenme Merkezi',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Yeni kelimeler öğren veya öğrendiklerini tekrar et.',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 24),
                    FutureBuilder<CategoryHubSnapshot>(
                      future: _categorySnapshot,
                      builder: (context, snapshot) {
                        final data = snapshot.data;
                        if (data == null &&
                            snapshot.connectionState != ConnectionState.done) {
                          return const _NewWordsLoadingCard();
                        }
                        final safeData =
                            data ??
                            const CategoryHubSnapshot(
                              progressByCategoryId: {},
                              recentCategories: [],
                            );
                        return _NewWordsCard(
                          snapshot: safeData,
                          categoryAccessService: widget.categoryAccessService,
                          onContinue: _openCategory,
                          onSelectCategory: () =>
                              _showCategorySelection(safeData),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    _LearningSummary(snapshot: _snapshot),
                    const SizedBox(height: 24),
                    Text(
                      'Çalışma ve Tekrar',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _StudyCard(
                      key: const ValueKey('learning-filter-repeat'),
                      icon: Icons.replay_rounded,
                      title: 'Tekrar Bekleyenler',
                      description: 'Çalışma zamanı gelen kelimeler',
                      count: _snapshot.repeatPendingCount,
                      onTap: () =>
                          _openFilter(LearningCenterFilter.repeatPending),
                    ),
                    const SizedBox(height: 12),
                    _StudyCard(
                      key: const ValueKey('learning-filter-favorites'),
                      icon: Icons.favorite_rounded,
                      title: 'Favorilerim',
                      description: 'Kaydettiğin kelimeleri yeniden çalış',
                      count: _snapshot.favoriteCount,
                      onTap: () => _openFilter(LearningCenterFilter.favorites),
                    ),
                    const SizedBox(height: 12),
                    _StudyCard(
                      key: const ValueKey('learning-filter-learned'),
                      icon: Icons.school_rounded,
                      title: 'Öğrenilenler',
                      description: 'Kolay olarak tamamladığın kelimeler',
                      count: _snapshot.learnedCount,
                      onTap: () => _openFilter(LearningCenterFilter.learned),
                    ),
                    const SizedBox(height: 12),
                    _StudyCard(
                      key: const ValueKey('learning-filter-all'),
                      icon: Icons.menu_book_rounded,
                      title: 'Tüm Kelimeler',
                      description:
                          'Bütün kategorilerdeki ${_snapshot.totalCount} kelime',
                      count: _snapshot.totalCount,
                      onTap: () => _openFilter(LearningCenterFilter.all),
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

class _LearningSummary extends StatelessWidget {
  const _LearningSummary({required this.snapshot});

  final LearningCenterSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Toplam kelime', snapshot.totalCount, Icons.menu_book_rounded),
      ('Favoriler', snapshot.favoriteCount, Icons.favorite_rounded),
      ('Tekrar bekleyenler', snapshot.repeatPendingCount, Icons.replay_rounded),
      ('Öğrenilenler', snapshot.learnedCount, Icons.school_rounded),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 680 ? 4 : 2;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: GlassSurface(
                  enableBlur: false,
                  showShadow: false,
                  padding: EdgeInsets.zero,
                  child: Card(
                    color: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            item.$3,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${item.$2}',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(item.$1, maxLines: 2),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _NewWordsLoadingCard extends StatelessWidget {
  const _NewWordsLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const GlassSurface(
      enableBlur: true,
      child: Padding(
        padding: AppDimensions.cardPadding,
        child: LinearProgressIndicator(),
      ),
    );
  }
}

class _NewWordsCard extends StatelessWidget {
  const _NewWordsCard({
    required this.snapshot,
    required this.categoryAccessService,
    required this.onContinue,
    required this.onSelectCategory,
  });

  final CategoryHubSnapshot snapshot;
  final CategoryAccessService? categoryAccessService;
  final ValueChanged<LearningCategory> onContinue;
  final VoidCallback onSelectCategory;

  @override
  Widget build(BuildContext context) {
    final category = _lastOpenCategory();
    final progress = category == null
        ? null
        : snapshot.progressFor(category.id);
    final learned = progress?.learnedWordCount ?? 0;
    final total = progress?.totalWordCount ?? category?.words.length ?? 0;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return GlassSurface(
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
              Text(
                'Yeni Kelimeler Öğren',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                category == null
                    ? 'Başlamak için açık bir kategori seç.'
                    : 'Kaldığın yerden devam et · ${category.title}',
              ),
              if (category != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: Text('$learned / $total kelime')),
                    Text(
                      '%${total == 0 ? 0 : (learned / total * 100).round()}',
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (category != null)
                    FilledButton.icon(
                      onPressed: () => onContinue(category),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Devam Et'),
                    ),
                  OutlinedButton.icon(
                    onPressed: onSelectCategory,
                    icon: const Icon(Icons.grid_view_rounded),
                    label: const Text('Kategori Seç'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  LearningCategory? _lastOpenCategory() {
    for (final category in snapshot.recentCategories) {
      if (categoryAccessService?.canOpen(category) ?? true) return category;
    }
    return null;
  }
}

class _StudyCard extends StatelessWidget {
  const _StudyCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.count,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 300;
        final iconSize = compact ? 44.0 : 52.0;
        return GlassSurface(
          enableBlur: false,
          showShadow: false,
          padding: EdgeInsets.zero,
          child: Card(
            color: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: compact
                    ? const EdgeInsets.all(16)
                    : AppDimensions.cardPadding,
                child: compact
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _StudyIcon(
                            icon: icon,
                            size: iconSize,
                            colorScheme: colorScheme,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StudyText(
                              title: title,
                              description: description,
                              count: count,
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      )
                    : Row(
                        children: [
                          _StudyIcon(
                            icon: icon,
                            size: iconSize,
                            colorScheme: colorScheme,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _StudyText(
                              title: title,
                              description: description,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '$count',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(width: 2),
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

class _StudyIcon extends StatelessWidget {
  const _StudyIcon({
    required this.icon,
    required this.size,
    required this.colorScheme,
  });

  final IconData icon;
  final double size;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: colorScheme.primary),
    );
  }
}

class _StudyText extends StatelessWidget {
  const _StudyText({
    required this.title,
    required this.description,
    this.count,
  });

  final String title;
  final String description;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 3),
        Text(description),
        if (count != null) ...[
          const SizedBox(height: 6),
          Text(
            '$count',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }
}
