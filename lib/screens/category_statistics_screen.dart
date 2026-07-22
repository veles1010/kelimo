import 'package:flutter/material.dart';
import 'package:kelimo/models/learning_category.dart';
import 'package:kelimo/models/progress_statistics.dart';
import 'package:kelimo/services/statistics_service.dart';
import 'package:kelimo/widgets/glass_surface.dart';

class CategoryStatisticsScreen extends StatefulWidget {
  const CategoryStatisticsScreen({
    required this.category,
    required this.statisticsService,
    super.key,
  });

  final LearningCategory category;
  final StatisticsService statisticsService;

  @override
  State<CategoryStatisticsScreen> createState() =>
      _CategoryStatisticsScreenState();
}

class _CategoryStatisticsScreenState extends State<CategoryStatisticsScreen> {
  late Future<CategoryProgressStatistics> _statistics;

  @override
  void initState() {
    super.initState();
    _statistics = widget.statisticsService.loadCategory(widget.category.id);
  }

  void _retry() {
    setState(() {
      _statistics = widget.statisticsService.loadCategory(widget.category.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('${widget.category.title} İstatistikleri'),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        body: FutureBuilder<CategoryProgressStatistics>(
          future: _statistics,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                child: FilledButton(
                  onPressed: _retry,
                  child: const Text('Tekrar Dene'),
                ),
              );
            }
            return _CategoryStatisticsContent(
              category: widget.category,
              statistics: snapshot.data!,
            );
          },
        ),
      ),
    );
  }
}

class _CategoryStatisticsContent extends StatelessWidget {
  const _CategoryStatisticsContent({
    required this.category,
    required this.statistics,
  });

  final LearningCategory category;
  final CategoryProgressStatistics statistics;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      (
        'Toplam kelime',
        '${statistics.totalWordCount}',
        Icons.menu_book_rounded,
      ),
      (
        'Değerlendirilen',
        '${statistics.reviewedWordCount}',
        Icons.fact_check_rounded,
      ),
      ('Öğrenilen', '${statistics.learnedWordCount}', Icons.school_rounded),
      ('Favori', '${statistics.favoriteWordCount}', Icons.favorite_rounded),
      (
        'Tamamlanan quiz',
        '${statistics.completedQuizCount}',
        Icons.quiz_rounded,
      ),
      (
        'En yüksek skor',
        '%${statistics.highestQuizScore}',
        Icons.emoji_events_rounded,
      ),
      (
        'Ortalama quiz',
        '%${statistics.averageQuizPercentage}',
        Icons.insights_rounded,
      ),
    ];
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final metricHeight = textScale > 1.25 ? 176.0 : 112.0;
    final masteryProgress = (statistics.averageMasteryPercentage / 100).clamp(
      0.0,
      1.0,
    );
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 28 + bottomInset),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GlassSurface(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Text(
                        category.emoji,
                        style: const TextStyle(fontSize: 40),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          '${category.title} performansı',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: metricHeight,
                  ),
                  itemCount: 4,
                  itemBuilder: (context, index) => _MetricCard(
                    label: metrics[index].$1,
                    value: metrics[index].$2,
                    icon: metrics[index].$3,
                  ),
                ),
                const SizedBox(height: 12),
                GlassSurface(
                  key: const ValueKey('average-mastery-card'),
                  enableBlur: false,
                  showShadow: false,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.trending_up_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(child: Text('Ortalama hâkimiyet')),
                          Text(
                            '%${statistics.averageMasteryPercentage}',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: masteryProgress,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: metricHeight,
                  ),
                  itemCount: metrics.length - 4,
                  itemBuilder: (context, index) {
                    final item = metrics[index + 4];
                    return _MetricCard(
                      label: item.$1,
                      value: item.$2,
                      icon: item.$3,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
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
    return GlassSurface(
      enableBlur: false,
      showShadow: false,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
          const SizedBox(height: 7),
          Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
