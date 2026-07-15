import 'package:flutter/material.dart';
import 'package:kelimo/models/learning_center.dart';
import 'package:kelimo/repositories/word_progress_repository.dart';
import 'package:kelimo/screens/learning_word_list_screen.dart';
import 'package:kelimo/services/learning_center_service.dart';
import 'package:kelimo/services/streak_service.dart';
import 'package:kelimo/services/xp_service.dart';
import 'package:kelimo/theme/app_theme.dart';

class LearningCenterScreen extends StatefulWidget {
  const LearningCenterScreen({
    required this.service,
    required this.wordProgressStore,
    required this.streakService,
    required this.xpService,
    super.key,
  });

  final LearningCenterService service;
  final WordProgressStore wordProgressStore;
  final StreakService streakService;
  final XpService xpService;

  @override
  State<LearningCenterScreen> createState() => _LearningCenterScreenState();
}

class _LearningCenterScreenState extends State<LearningCenterScreen> {
  late LearningCenterSnapshot _snapshot;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.service.load();
  }

  void _reload() {
    setState(() => _snapshot = widget.service.load());
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
        ),
      ),
    );
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Öğrenme Merkezi',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Kelimelerini durumlarına göre yeniden çalış.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 24),
                  _LearningSummary(snapshot: _snapshot),
                  const SizedBox(height: 24),
                  _StudyCard(
                    key: const ValueKey('learning-filter-repeat'),
                    icon: Icons.replay_rounded,
                    title: 'Tekrar Bekleyenler',
                    description:
                        'Tekrar Et veya Zor olarak işaretlediğin kelimeler',
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
                child: Card(
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
          ],
        );
      },
    );
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: AppDimensions.cardPadding,
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(description),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$count',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
