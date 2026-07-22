import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kelimo/models/review_session.dart';
import 'package:kelimo/repositories/word_progress_repository.dart';
import 'package:kelimo/services/english_tts_service.dart';
import 'package:kelimo/services/achievement_service.dart';
import 'package:kelimo/services/daily_reminder_service.dart';
import 'package:kelimo/services/learning_engine.dart';
import 'package:kelimo/services/review_session_builder.dart';
import 'package:kelimo/services/settings_service.dart';
import 'package:kelimo/services/streak_service.dart';
import 'package:kelimo/services/xp_service.dart';
import 'package:kelimo/widgets/learning_flashcard.dart';
import 'package:kelimo/widgets/achievement_notification.dart';

enum ReviewSessionExit { learningCenter }

class ReviewSessionScreen extends StatefulWidget {
  const ReviewSessionScreen({
    required this.initialItems,
    required this.sessionBuilder,
    required this.wordProgressStore,
    required this.streakService,
    required this.xpService,
    required this.settingsService,
    super.key,
    this.ttsService,
    this.achievementService,
    this.dailyReminderService,
  }) : assert(initialItems.length > 0);

  final List<ReviewSessionItem> initialItems;
  final ReviewSessionBuilder sessionBuilder;
  final WordProgressStore wordProgressStore;
  final StreakService streakService;
  final XpService xpService;
  final SettingsService settingsService;
  final EnglishTtsService? ttsService;
  final AchievementService? achievementService;
  final DailyReminderService? dailyReminderService;

  @override
  State<ReviewSessionScreen> createState() => _ReviewSessionScreenState();
}

class _ReviewSessionScreenState extends State<ReviewSessionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;
  late final EnglishTtsService _ttsService;
  late List<ReviewSessionItem> _items;
  ReviewSessionCounter _counter = ReviewSessionCounter();
  LearningRating? _selectedRating;
  int _index = 0;
  int _remainingDueCount = 0;
  bool _isEvaluating = false;
  bool _isSavingFavorite = false;
  bool _isCompleted = false;
  bool _isExitDialogOpen = false;
  late bool _isFavorite;

  ReviewSessionItem get _currentItem => _items[_index];

  @override
  void initState() {
    super.initState();
    _items = List.unmodifiable(widget.initialItems);
    _ttsService =
        widget.ttsService ??
        EnglishTtsService(settingsService: widget.settingsService);
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );
    _flipAnimation = CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOut,
    );
    _syncFavorite();
  }

  @override
  void dispose() {
    if (widget.ttsService == null) unawaited(_ttsService.dispose());
    _flipController.dispose();
    super.dispose();
  }

  void _flipCard() {
    if (_flipController.isCompleted) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
  }

  void _syncFavorite() {
    _isFavorite = widget.wordProgressStore
        .progressFor(_currentItem.word.id)
        .isFavorite;
  }

  Future<void> _speakWord() async {
    final didSpeak = await _ttsService.speak(_currentItem.word.english);
    if (!didSpeak && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ses oynatılamadı')));
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isSavingFavorite || _isEvaluating) return;
    final wordId = _currentItem.word.id;
    final nextValue = !_isFavorite;
    setState(() {
      _isSavingFavorite = true;
      _isFavorite = nextValue;
    });
    try {
      await widget.wordProgressStore.saveFavorite(wordId, nextValue);
      if (nextValue) await _evaluateAchievements();
    } catch (_) {
      if (mounted && _currentItem.word.id == wordId) {
        setState(() => _isFavorite = !nextValue);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Favori kaydedilemedi')));
      }
    } finally {
      if (mounted) setState(() => _isSavingFavorite = false);
    }
  }

  Future<void> _evaluate(LearningRating rating) async {
    if (_isEvaluating || _isCompleted) return;
    setState(() {
      _isEvaluating = true;
      _selectedRating = rating;
    });

    final engine = LearningEngine([_currentItem.word]);
    switch (rating) {
      case LearningRating.easy:
        engine.rateEasy();
        break;
      case LearningRating.again:
        engine.rateAgain();
        break;
      case LearningRating.hard:
        engine.rateHard();
        break;
    }

    try {
      await widget.wordProgressStore.saveLearningResult(engine.lastReview!);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _selectedRating = null;
      });
      _unlockEvaluationAfterFrame();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('İlerleme kaydedilemedi')));
      return;
    }

    final completedDailyGoal = await widget.streakService.recordEvaluation();
    final xpSaved = await widget.xpService.awardWordReview(
      wordId: _currentItem.word.id,
      rating: rating,
    );
    if (!xpSaved && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('XP kaydedilemedi')));
    }
    if (completedDailyGoal && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🔥 Günlük hedef tamamlandı! Serin '
            '${widget.streakService.currentStreak} güne çıktı.',
          ),
        ),
      );
    }
    await _evaluateAchievements();
    await widget.dailyReminderService?.refreshSchedule();

    _counter.record(rating);
    unawaited(_ttsService.stop());
    _flipController.reset();
    if (!mounted) return;

    if (_index + 1 < _items.length) {
      setState(() {
        _index++;
        _selectedRating = null;
        _syncFavorite();
      });
      _unlockEvaluationAfterFrame();
      return;
    }

    var remainingDueCount = 0;
    try {
      remainingDueCount = (await widget.sessionBuilder.build()).length;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bekleyen kelimeler yenilenemedi')),
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _remainingDueCount = remainingDueCount;
      _selectedRating = null;
      _isEvaluating = false;
      _isCompleted = true;
    });
  }

  Future<void> _evaluateAchievements() async {
    final service = widget.achievementService;
    if (service == null) return;
    try {
      final unlocked = await service.evaluate();
      if (mounted) await showAchievementNotifications(context, unlocked);
    } catch (_) {
      // Başarım kontrolü tekrar oturumunu engellememeli.
    }
  }

  void _unlockEvaluationAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _isEvaluating = false);
    });
  }

  Future<void> _restartPending() async {
    List<ReviewSessionItem> items;
    try {
      items = await widget.sessionBuilder.build();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tekrar oturumu başlatılamadı')),
        );
      }
      return;
    }
    if (!mounted || items.isEmpty) return;
    await _ttsService.stop();
    _flipController.reset();
    setState(() {
      _items = items;
      _counter = ReviewSessionCounter();
      _index = 0;
      _remainingDueCount = 0;
      _selectedRating = null;
      _isEvaluating = false;
      _isCompleted = false;
      _syncFavorite();
    });
  }

  Future<void> _requestExit() async {
    if (_isEvaluating) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('İlerleme kaydediliyor')));
      return;
    }
    if (_isCompleted) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    if (_isExitDialogOpen) return;
    _isExitDialogOpen = true;
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Oturumdan çıkılsın mı?'),
        content: const Text(
          'Tamamladığın kelimeler kaydedildi. Kalan kelimeleri daha sonra '
          'çalışabilirsin.',
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Devam Et'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Çık'),
          ),
        ],
      ),
    );
    _isExitDialogOpen = false;
    if (shouldExit == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _isCompleted,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_requestExit());
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => unawaited(_requestExit()),
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Kapat',
          ),
          title: const Text('Tekrar Oturumu'),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          actions: [
            if (!_isCompleted)
              Padding(
                padding: const EdgeInsets.only(right: 24),
                child: Center(child: Text('${_index + 1} / ${_items.length}')),
              ),
          ],
        ),
        body: _isCompleted ? _buildResult() : _buildSession(),
      ),
    );
  }

  Widget _buildSession() {
    final item = _currentItem;
    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LinearProgressIndicator(value: (_index + 1) / _items.length),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(
                      key: const ValueKey('review-category-chip'),
                      avatar: Text(item.category.emoji),
                      label: Text(item.category.title),
                    ),
                  ),
                  const SizedBox(height: 12),
                  LearningFlashcard(
                    animation: _flipAnimation,
                    onTap: _flipCard,
                    word: item.word,
                  ),
                  const SizedBox(height: 20),
                  ValueListenableBuilder<bool>(
                    valueListenable: _ttsService.isSpeaking,
                    builder: (context, isSpeaking, child) {
                      return LearningWordActions(
                        isSpeaking: isSpeaking,
                        isFavorite: _isFavorite,
                        enabled: !_isEvaluating && !_isSavingFavorite,
                        onListen: () => unawaited(_speakWord()),
                        onFavorite: () => unawaited(_toggleFavorite()),
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  LearningRatingSection(
                    selectedRating: _selectedRating,
                    enabled: !_isEvaluating && !_isSavingFavorite,
                    onSelected: (rating) => unawaited(_evaluate(rating)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final summary = _counter.summary(_items.length);
    final displayedTodayCount = math.min(
      widget.streakService.todayCount,
      widget.streakService.dailyGoal,
    );
    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.task_alt_rounded,
                    size: 72,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tekrar tamamlandı!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _ResultRow(
                    key: const ValueKey('review-result-total'),
                    label: 'Çalışılan kelime',
                    value: '${summary.totalCount}',
                  ),
                  _ResultRow(
                    key: const ValueKey('review-result-easy'),
                    label: 'Kolay',
                    value: '${summary.easyCount}',
                  ),
                  _ResultRow(
                    key: const ValueKey('review-result-again'),
                    label: 'Tekrar Et',
                    value: '${summary.againCount}',
                  ),
                  _ResultRow(
                    key: const ValueKey('review-result-hard'),
                    label: 'Zor',
                    value: '${summary.hardCount}',
                  ),
                  _ResultRow(
                    key: const ValueKey('review-result-daily'),
                    label: 'Günlük hedef ilerlemesi',
                    value:
                        '$displayedTodayCount / '
                        '${widget.streakService.dailyGoal}',
                  ),
                  if (widget.streakService.isTodayCompleted) ...[
                    const SizedBox(height: 12),
                    Text(
                      '🔥 Günlük hedef tamamlandı!',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const ValueKey('review-return-learning-center'),
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(ReviewSessionExit.learningCenter),
                    child: const Text('Öğrenme Merkezine Dön'),
                  ),
                  if (_remainingDueCount > 0) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const ValueKey('review-restart-pending'),
                      onPressed: () => unawaited(_restartPending()),
                      icon: const Icon(Icons.replay_rounded),
                      label: const Text('Bekleyenleri Tekrar Çalış'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
