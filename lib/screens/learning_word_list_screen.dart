import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kelimo/models/learning_center.dart';
import 'package:kelimo/repositories/word_progress_repository.dart';
import 'package:kelimo/screens/word_card_screen.dart';
import 'package:kelimo/screens/review_session_screen.dart';
import 'package:kelimo/services/learning_center_service.dart';
import 'package:kelimo/services/achievement_service.dart';
import 'package:kelimo/services/daily_reminder_service.dart';
import 'package:kelimo/services/review_session_builder.dart';
import 'package:kelimo/services/settings_service.dart';
import 'package:kelimo/services/streak_service.dart';
import 'package:kelimo/services/xp_service.dart';
import 'package:kelimo/widgets/achievement_notification.dart';
import 'package:kelimo/widgets/glass_surface.dart';

class LearningWordListScreen extends StatefulWidget {
  const LearningWordListScreen({
    required this.filter,
    required this.service,
    required this.wordProgressStore,
    required this.streakService,
    required this.xpService,
    required this.settingsService,
    super.key,
    this.sessionBuilder,
    this.achievementService,
    this.dailyReminderService,
  });

  final LearningCenterFilter filter;
  final LearningCenterService service;
  final WordProgressStore wordProgressStore;
  final StreakService streakService;
  final XpService xpService;
  final SettingsService settingsService;
  final ReviewSessionBuilder? sessionBuilder;
  final AchievementService? achievementService;
  final DailyReminderService? dailyReminderService;

  @override
  State<LearningWordListScreen> createState() => _LearningWordListScreenState();
}

class _LearningWordListScreenState extends State<LearningWordListScreen> {
  late List<LearningCenterWord> _words;
  late final ReviewSessionBuilder _sessionBuilder;
  bool _isStartingSession = false;
  final Set<String> _savingFavorites = <String>{};

  @override
  void initState() {
    super.initState();
    _sessionBuilder =
        widget.sessionBuilder ??
        ReviewSessionBuilder(wordProgressStore: widget.wordProgressStore);
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
          settingsService: widget.settingsService,
          achievementService: widget.achievementService,
          dailyReminderService: widget.dailyReminderService,
        ),
      ),
    );
    if (mounted) setState(_reload);
  }

  Future<void> _startReviewSession() async {
    if (_isStartingSession) return;
    setState(() => _isStartingSession = true);
    try {
      final items = await _sessionBuilder.build();
      if (!mounted) return;
      if (items.isEmpty) {
        setState(_reload);
        return;
      }
      final result = await Navigator.of(context).push<ReviewSessionExit>(
        MaterialPageRoute<ReviewSessionExit>(
          builder: (_) => ReviewSessionScreen(
            initialItems: items,
            sessionBuilder: _sessionBuilder,
            wordProgressStore: widget.wordProgressStore,
            streakService: widget.streakService,
            xpService: widget.xpService,
            settingsService: widget.settingsService,
            achievementService: widget.achievementService,
            dailyReminderService: widget.dailyReminderService,
          ),
        ),
      );
      if (!mounted) return;
      if (result == ReviewSessionExit.learningCenter) {
        Navigator.of(context).pop();
        return;
      }
      setState(_reload);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tekrar oturumu başlatılamadı')),
        );
      }
    } finally {
      if (mounted) setState(() => _isStartingSession = false);
    }
  }

  Future<void> _toggleFavorite(LearningCenterWord entry) async {
    final wordId = entry.word.id;
    if (_savingFavorites.contains(wordId)) return;
    final nextValue = !entry.progress.isFavorite;
    setState(() => _savingFavorites.add(wordId));
    try {
      await widget.wordProgressStore.saveFavorite(wordId, nextValue);
      if (nextValue) {
        final service = widget.achievementService;
        if (service != null) {
          final unlocked = await service.evaluate();
          if (mounted) await showAchievementNotifications(context, unlocked);
        }
      }
      if (mounted) setState(_reload);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Favori kaydedilemedi')));
      }
    } finally {
      if (mounted) setState(() => _savingFavorites.remove(wordId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(_titleFor(widget.filter)),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        body: _words.isEmpty
            ? _EmptyState(message: _emptyMessageFor(widget.filter))
            : ListView.separated(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 28 + bottomInset),
                itemCount:
                    _words.length +
                    (widget.filter == LearningCenterFilter.repeatPending
                        ? 1
                        : 0),
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (widget.filter == LearningCenterFilter.repeatPending &&
                      index == 0) {
                    return FilledButton.icon(
                      key: const ValueKey('start-review-session'),
                      onPressed: _isStartingSession
                          ? null
                          : () => unawaited(_startReviewSession()),
                      icon: _isStartingSession
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow_rounded),
                      label: Text('${_words.length} kelimeyi çalış'),
                    );
                  }
                  final wordIndex =
                      index -
                      (widget.filter == LearningCenterFilter.repeatPending
                          ? 1
                          : 0);
                  final entry = _words[wordIndex];
                  return _WordRow(
                    key: ValueKey('learning-word-${entry.word.id}'),
                    entry: entry,
                    onTap: () => _openWord(entry),
                    onFavorite: () => unawaited(_toggleFavorite(entry)),
                    isSavingFavorite: _savingFavorites.contains(entry.word.id),
                  );
                },
              ),
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
        child: GlassSurface(
          enableBlur: false,
          showShadow: false,
          padding: const EdgeInsets.all(24),
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
      ),
    );
  }
}

class _WordRow extends StatelessWidget {
  const _WordRow({
    required this.entry,
    required this.onTap,
    required this.onFavorite,
    required this.isSavingFavorite,
    super.key,
  });

  final LearningCenterWord entry;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final bool isSavingFavorite;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GlassSurface(
      enableBlur: false,
      showShadow: false,
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
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
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
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
                          _Label(
                            text: entry.category.title,
                            tone: _LabelTone.category,
                          ),
                          _Label(
                            text: entry.status.label,
                            tone: switch (entry.status) {
                              LearningCenterWordStatus.newWord =>
                                _LabelTone.newWord,
                              LearningCenterWordStatus.learning =>
                                _LabelTone.learning,
                              LearningCenterWordStatus.learned =>
                                _LabelTone.learned,
                            },
                          ),
                          if (entry.reviewTimeLabel case final label?)
                            _Label(
                              text: label,
                              tone: _LabelTone.review,
                              key: ValueKey('review-time-${entry.word.id}'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: ValueKey('favorite-${entry.word.id}'),
                  tooltip: entry.progress.isFavorite
                      ? 'Favorilerden çıkar'
                      : 'Favorilere ekle',
                  onPressed: isSavingFavorite ? null : onFavorite,
                  icon: isSavingFavorite
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          entry.progress.isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: entry.progress.isFavorite
                              ? colorScheme.secondary
                              : colorScheme.outline,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _LabelTone { category, newWord, learning, learned, review }

class _Label extends StatelessWidget {
  const _Label({required this.text, required this.tone, super.key});

  final String text;
  final _LabelTone tone;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = switch (tone) {
      _LabelTone.category => colorScheme.primary,
      _LabelTone.newWord => colorScheme.outline,
      _LabelTone.learning => colorScheme.secondary,
      _LabelTone.learned => colorScheme.tertiary,
      _LabelTone.review => colorScheme.primary,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
