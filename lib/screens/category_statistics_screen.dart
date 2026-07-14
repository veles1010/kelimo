import 'package:flutter/material.dart';
import 'package:kelimo/models/progress_statistics.dart';
import 'package:kelimo/services/statistics_service.dart';

class CategoryStatisticsScreen extends StatefulWidget {
  const CategoryStatisticsScreen({
    required this.categoryId,
    required this.statisticsService,
    super.key,
  });

  final String categoryId;
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
    _statistics = widget.statisticsService.loadCategory(widget.categoryId);
  }

  void _retry() {
    setState(() {
      _statistics = widget.statisticsService.loadCategory(widget.categoryId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hayvanlar İstatistikleri'),
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
          return _CategoryStatisticsContent(statistics: snapshot.data!);
        },
      ),
    );
  }
}

class _CategoryStatisticsContent extends StatelessWidget {
  const _CategoryStatisticsContent({required this.statistics});

  final CategoryProgressStatistics statistics;

  @override
  Widget build(BuildContext context) {
    final items = [
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
        'Ortalama mastery',
        '%${statistics.averageMasteryPercentage}',
        Icons.trending_up_rounded,
      ),
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        const Text('🐶', style: TextStyle(fontSize: 40)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            '${statistics.categoryName} performansı',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth < 380 ? 1 : 2;
                    final width =
                        (constraints.maxWidth - (columns - 1) * 12) / columns;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final item in items)
                          SizedBox(
                            width: width,
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      item.$3,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(item.$1),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.$2,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
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
