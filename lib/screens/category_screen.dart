import 'package:flutter/material.dart';
import 'package:kelimo/models/learning_category.dart';
import 'package:kelimo/models/progress_statistics.dart';
import 'package:kelimo/repositories/quiz_repository.dart';
import 'package:kelimo/repositories/word_progress_repository.dart';
import 'package:kelimo/screens/category_quiz_screen.dart';
import 'package:kelimo/screens/category_statistics_screen.dart';
import 'package:kelimo/screens/word_card_screen.dart';
import 'package:kelimo/services/streak_service.dart';
import 'package:kelimo/services/statistics_service.dart';
import 'package:kelimo/services/settings_service.dart';
import 'package:kelimo/services/xp_service.dart';
import 'package:kelimo/theme/app_theme.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({
    required this.category,
    required this.streakService,
    required this.wordProgressStore,
    required this.xpService,
    required this.quizStore,
    required this.statisticsService,
    required this.settingsService,
    super.key,
  });

  final LearningCategory category;
  final StreakService streakService;
  final WordProgressStore wordProgressStore;
  final XpService xpService;
  final QuizStore quizStore;
  final StatisticsService statisticsService;
  final SettingsService settingsService;

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  late Future<CategoryProgressStatistics> _categoryProgress;

  @override
  void initState() {
    super.initState();
    _categoryProgress = widget.statisticsService.loadCategory(
      widget.category.id,
    );
  }

  void _reloadCategoryProgress() {
    setState(() {
      _categoryProgress = widget.statisticsService.loadCategory(
        widget.category.id,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final streakService = widget.streakService;
    final wordProgressStore = widget.wordProgressStore;
    final xpService = widget.xpService;
    final quizStore = widget.quizStore;
    final statisticsService = widget.statisticsService;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CategoryHeader(category: widget.category),
                    const SizedBox(height: 24),
                    _CategoryProgressCard(
                      statistics: _categoryProgress,
                      totalWordCount: widget.category.words.length,
                    ),
                    const SizedBox(height: 24),
                    _ActionCard(
                      icon: Icons.school_rounded,
                      title: 'Öğrenmeye Başla',
                      subtitle: 'Kelime kartlarıyla çalış',
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => WordCardScreen(
                              category: widget.category,
                              streakService: streakService,
                              wordProgressStore: wordProgressStore,
                              xpService: xpService,
                              settingsService: widget.settingsService,
                            ),
                          ),
                        );
                        if (mounted) {
                          _reloadCategoryProgress();
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _ActionCard(
                      icon: Icons.quiz_rounded,
                      title: 'Quiz Çöz',
                      subtitle: 'Bilgini test et',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => CategoryQuizScreen(
                              category: widget.category,
                              quizStore: quizStore,
                              xpService: xpService,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _ActionCard(
                      icon: Icons.insights_rounded,
                      title: 'İstatistik',
                      subtitle: 'Kategori performansını gör',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => CategoryStatisticsScreen(
                              category: widget.category,
                              statisticsService: statisticsService,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    _RecentStudies(category: widget.category),
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

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.category});

  final LearningCategory category;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          ),
          child: Text(category.emoji, style: const TextStyle(fontSize: 36)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category.title,
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${category.words.length} kelime',
                style: textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryProgressCard extends StatelessWidget {
  const _CategoryProgressCard({
    required this.statistics,
    required this.totalWordCount,
  });

  final Future<CategoryProgressStatistics> statistics;
  final int totalWordCount;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CategoryProgressStatistics>(
      future: statistics,
      builder: (context, snapshot) {
        final category = snapshot.data;
        final total = category?.totalWordCount ?? totalWordCount;
        final learned = category?.learnedWordCount ?? 0;
        final progress = total == 0 ? 0.0 : learned / total;
        final percentage = (progress * 100).round();

        return _buildCard(context, learned, total, progress, percentage);
      },
    );
  }

  Widget _buildCard(
    BuildContext context,
    int learned,
    int total,
    double progress,
    int percentage,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: AppDimensions.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kategori ilerlemesi',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$learned / $total kelime',
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 18),
            LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              borderRadius: BorderRadius.circular(6),
            ),
            const SizedBox(height: 12),
            Text(
              '%$percentage tamamlandı',
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final content = Padding(
      padding: AppDimensions.cardPadding,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle),
              ],
            ),
          ),
        ],
      ),
    );

    return Card(
      clipBehavior: onTap == null ? Clip.none : Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

class _RecentStudies extends StatelessWidget {
  const _RecentStudies({required this.category});

  final LearningCategory category;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Son çalışmalar',
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: AppDimensions.cardPadding,
            child: Column(
              children: [
                for (final (index, word) in category.words.take(3).indexed) ...[
                  if (index > 0) const Divider(height: 24),
                  _WordRow(english: word.english, turkish: word.turkish),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WordRow extends StatelessWidget {
  const _WordRow({required this.english, required this.turkish});

  final String english;
  final String turkish;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            english,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Text(turkish, style: textTheme.titleMedium),
      ],
    );
  }
}
