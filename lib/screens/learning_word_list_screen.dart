import 'package:flutter/material.dart';
import 'package:kelimo/models/learning_center.dart';
import 'package:kelimo/repositories/word_progress_repository.dart';
import 'package:kelimo/screens/word_card_screen.dart';
import 'package:kelimo/services/learning_center_service.dart';
import 'package:kelimo/services/streak_service.dart';
import 'package:kelimo/services/xp_service.dart';

class LearningWordListScreen extends StatefulWidget {
  const LearningWordListScreen({
    required this.filter,
    required this.service,
    required this.wordProgressStore,
    required this.streakService,
    required this.xpService,
    super.key,
  });

  final LearningCenterFilter filter;
  final LearningCenterService service;
  final WordProgressStore wordProgressStore;
  final StreakService streakService;
  final XpService xpService;

  @override
  State<LearningWordListScreen> createState() => _LearningWordListScreenState();
}

class _LearningWordListScreenState extends State<LearningWordListScreen> {
  late List<LearningCenterWord> _words;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _words = widget.service.load().wordsFor(widget.filter);
  }

  Future<void> _openWord(LearningCenterWord entry) async {
    final initialWordIndex = entry.category.words.indexWhere(
      (word) => word.id == entry.word.id,
    );
    if (initialWordIndex < 0) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WordCardScreen(
          category: entry.category,
          initialWordIndex: initialWordIndex,
          wordProgressStore: widget.wordProgressStore,
          streakService: widget.streakService,
          xpService: widget.xpService,
        ),
      ),
    );
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titleFor(widget.filter)),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: _words.isEmpty
          ? _EmptyState(message: _emptyMessageFor(widget.filter))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              itemCount: _words.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final entry = _words[index];
                return _WordRow(
                  key: ValueKey('learning-word-${entry.word.id}'),
                  entry: entry,
                  onTap: () => _openWord(entry),
                );
              },
            ),
    );
  }
}

String _titleFor(LearningCenterFilter filter) {
  return switch (filter) {
    LearningCenterFilter.repeatPending => 'Tekrar Bekleyenler',
    LearningCenterFilter.favorites => 'Favorilerim',
    LearningCenterFilter.learned => 'Öğrenilenler',
    LearningCenterFilter.all => 'Tüm Kelimeler',
  };
}

String _emptyMessageFor(LearningCenterFilter filter) {
  return switch (filter) {
    LearningCenterFilter.repeatPending => 'Tekrar bekleyen kelimen yok.',
    LearningCenterFilter.favorites => 'Henüz favori kelimen yok.',
    LearningCenterFilter.learned => 'Henüz öğrenilen kelimen yok.',
    LearningCenterFilter.all => 'Henüz kelime bulunmuyor.',
  };
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_stories_rounded,
              size: 52,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _WordRow extends StatelessWidget {
  const _WordRow({required this.entry, required this.onTap, super.key});

  final LearningCenterWord entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(entry.word.emoji, style: const TextStyle(fontSize: 34)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.word.english,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      entry.word.turkish,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _Label(text: entry.category.title),
                        _Label(text: entry.status.label),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                entry.progress.isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: entry.progress.isFavorite
                    ? colorScheme.secondary
                    : colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(text, style: Theme.of(context).textTheme.labelSmall),
      ),
    );
  }
}
