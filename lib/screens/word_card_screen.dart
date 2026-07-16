import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kelimo/models/learning_category.dart';
import 'package:kelimo/repositories/word_progress_repository.dart';
import 'package:kelimo/services/english_tts_service.dart';
import 'package:kelimo/services/achievement_service.dart';
import 'package:kelimo/services/learning_engine.dart';
import 'package:kelimo/services/settings_service.dart';
import 'package:kelimo/services/streak_service.dart';
import 'package:kelimo/services/xp_service.dart';
import 'package:kelimo/widgets/learning_flashcard.dart';
import 'package:kelimo/widgets/achievement_notification.dart';

class WordCardScreen extends StatefulWidget {
  WordCardScreen({
    required this.category,
    required this.wordProgressStore,
    required this.xpService,
    super.key,
    this.ttsService,
    this.streakService,
    this.initialWordIndex = 0,
    this.settingsService,
    this.achievementService,
  }) : assert(
         initialWordIndex >= 0 && initialWordIndex < category.words.length,
       );

  final LearningCategory category;
  final WordProgressStore wordProgressStore;
  final XpService xpService;
  final EnglishTtsService? ttsService;
  final StreakService? streakService;
  final int initialWordIndex;
  final SettingsService? settingsService;
  final AchievementService? achievementService;

  @override
  State<WordCardScreen> createState() => _WordCardScreenState();
}

class _WordCardScreenState extends State<WordCardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;
  late final EnglishTtsService _ttsService;
  late final LearningEngine _learningEngine;
  late final StreakService _streakService;
  late final bool _ownsStreakService;
  LearningRating? _selectedDifficulty;
  bool _isEvaluating = false;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _ttsService =
        widget.ttsService ??
        EnglishTtsService(settingsService: widget.settingsService);
    _learningEngine = LearningEngine(
      widget.category.words,
      initialWordIndex: widget.initialWordIndex,
    );
    _ownsStreakService = widget.streakService == null;
    _streakService = widget.streakService ?? StreakService();
    _isFavorite = widget.wordProgressStore
        .progressFor(_learningEngine.currentWord.id)
        .isFavorite;
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );
    _flipAnimation = CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    unawaited(_ttsService.dispose());
    if (_ownsStreakService) _streakService.dispose();
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

  void _showNextWord() {
    if (!_learningEngine.canNext || _isEvaluating) return;

    unawaited(_ttsService.stop());
    _flipController.reset();
    setState(() {
      _learningEngine.nextWord();
      _selectedDifficulty = null;
      _syncFavoriteState();
    });
  }

  void _showPreviousWord() {
    if (!_learningEngine.canPrevious || _isEvaluating) return;

    unawaited(_ttsService.stop());
    _flipController.reset();
    setState(() {
      _learningEngine.previousWord();
      _selectedDifficulty = null;
      _syncFavoriteState();
    });
  }

  Future<void> _evaluateWord(LearningRating rating) async {
    if (_isEvaluating || _learningEngine.isComplete) return;

    setState(() {
      _selectedDifficulty = rating;
      _isEvaluating = true;
    });
    final dailyProgress = _streakService.recordEvaluation();

    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;

    unawaited(_ttsService.stop());
    _flipController.reset();

    late final LearningReviewResult learningResult;
    setState(() {
      switch (rating) {
        case LearningRating.easy:
          _learningEngine.rateEasy();
          break;
        case LearningRating.again:
          _learningEngine.rateAgain();
          break;
        case LearningRating.hard:
          _learningEngine.rateHard();
          break;
      }
      learningResult = _learningEngine.lastReview!;
      _selectedDifficulty = null;
      _isEvaluating = false;
      _syncFavoriteState();
    });

    var progressSaved = false;
    try {
      await widget.wordProgressStore.saveLearningResult(learningResult);
      progressSaved = true;
      final xpSaved = await widget.xpService.addXp(
        xpRewardForRating(learningResult.rating),
      );
      if (!xpSaved && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('XP kaydedilemedi')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('İlerleme kaydedilemedi')));
      }
    }

    final completedDailyGoal = await dailyProgress;
    if (completedDailyGoal && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🔥 Günlük hedef tamamlandı! Serin '
            '${_streakService.currentStreak} güne çıktı.',
          ),
        ),
      );
    }

    if (progressSaved) await _evaluateAchievements();

    if (_learningEngine.isComplete) await _showCompletionDialog();
  }

  void _syncFavoriteState() {
    _isFavorite = widget.wordProgressStore
        .progressFor(_learningEngine.currentWord.id)
        .isFavorite;
  }

  Future<void> _toggleFavorite() async {
    final wordId = _learningEngine.currentWord.id;
    final isFavorite = !_isFavorite;
    setState(() => _isFavorite = isFavorite);

    try {
      await widget.wordProgressStore.saveFavorite(wordId, isFavorite);
      if (isFavorite) await _evaluateAchievements();
    } catch (_) {
      if (!mounted) return;
      if (_learningEngine.currentWord.id == wordId) {
        setState(() => _isFavorite = !isFavorite);
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Favori kaydedilemedi')));
    }
  }

  Future<void> _evaluateAchievements() async {
    final service = widget.achievementService;
    if (service == null) return;
    try {
      final unlocked = await service.evaluate();
      if (mounted) await showAchievementNotifications(context, unlocked);
    } catch (_) {
      // Başarım kontrolü temel öğrenme akışını engellememeli.
    }
  }

  Future<void> _showCompletionDialog() {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.celebration_rounded,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: const Text('Kategori Tamamlandı'),
        content: Text(
          '${widget.category.title} kategorisindeki tüm kelimeleri '
          'tamamladın!',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  Future<void> _speakWord() async {
    final didSpeak = await _ttsService.speak(
      _learningEngine.currentWord.english,
    );
    if (!didSpeak && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ses oynatılamadı')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final word = _learningEngine.currentWord;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(widget.category.title),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 24),
            child: Center(
              child: Text(
                '${_learningEngine.currentWordNumber} / '
                '${_learningEngine.totalWordCount}',
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LearningFlashcard(
                      animation: _flipAnimation,
                      onTap: _flipCard,
                      word: word,
                    ),
                    const SizedBox(height: 20),
                    ValueListenableBuilder<bool>(
                      valueListenable: _ttsService.isSpeaking,
                      builder: (context, isSpeaking, child) {
                        return LearningWordActions(
                          isSpeaking: isSpeaking,
                          isFavorite: _isFavorite,
                          onListen: () => unawaited(_speakWord()),
                          onFavorite: () => unawaited(_toggleFavorite()),
                        );
                      },
                    ),
                    const SizedBox(height: 28),
                    LearningRatingSection(
                      selectedRating: _selectedDifficulty,
                      enabled: !_isEvaluating && !_learningEngine.isComplete,
                      onSelected: (rating) => unawaited(_evaluateWord(rating)),
                    ),
                    const SizedBox(height: 28),
                    _WordNavigation(
                      onPrevious: !_learningEngine.canPrevious || _isEvaluating
                          ? null
                          : _showPreviousWord,
                      onNext: !_learningEngine.canNext || _isEvaluating
                          ? null
                          : _showNextWord,
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

class _WordNavigation extends StatelessWidget {
  const _WordNavigation({required this.onPrevious, required this.onNext});

  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPrevious,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Önceki'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: onNext,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Sonraki'),
          ),
        ),
      ],
    );
  }
}
