import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kelimo/data/animal_words.dart';
import 'package:kelimo/models/word.dart';
import 'package:kelimo/repositories/word_progress_repository.dart';
import 'package:kelimo/services/english_tts_service.dart';
import 'package:kelimo/services/learning_engine.dart';
import 'package:kelimo/services/streak_service.dart';
import 'package:kelimo/utils/turkish_case.dart';

class WordCardScreen extends StatefulWidget {
  const WordCardScreen({
    required this.wordProgressStore,
    super.key,
    this.ttsService,
    this.streakService,
  });

  final WordProgressStore wordProgressStore;
  final EnglishTtsService? ttsService;
  final StreakService? streakService;

  @override
  State<WordCardScreen> createState() => _WordCardScreenState();
}

enum _LearningRating {
  easy('Kolay'),
  repeat('Tekrar Et'),
  hard('Zor');

  const _LearningRating(this.label);

  final String label;
}

class _WordCardScreenState extends State<WordCardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;
  late final EnglishTtsService _ttsService;
  late final LearningEngine _learningEngine;
  late final StreakService _streakService;
  late final bool _ownsStreakService;
  _LearningRating? _selectedDifficulty;
  bool _isEvaluating = false;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _ttsService = widget.ttsService ?? EnglishTtsService();
    _learningEngine = LearningEngine(animalWords);
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

  Future<void> _evaluateWord(_LearningRating rating) async {
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
        case _LearningRating.easy:
          _learningEngine.rateEasy();
          break;
        case _LearningRating.repeat:
          _learningEngine.rateAgain();
          break;
        case _LearningRating.hard:
          _learningEngine.rateHard();
          break;
      }
      learningResult = _learningEngine.lastReview!;
      _selectedDifficulty = null;
      _isEvaluating = false;
      _syncFavoriteState();
    });

    try {
      await widget.wordProgressStore.saveLearningResult(learningResult);
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

  Future<void> _showCompletionDialog() {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.celebration_rounded,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: const Text('Kategori Tamamlandı'),
        content: const Text(
          'Hayvanlar kategorisindeki tüm kelimeleri tamamladın!',
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
        title: const Text('Hayvanlar'),
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
                    _FlippableWordCard(
                      animation: _flipAnimation,
                      onTap: _flipCard,
                      word: word,
                    ),
                    const SizedBox(height: 20),
                    ValueListenableBuilder<bool>(
                      valueListenable: _ttsService.isSpeaking,
                      builder: (context, isSpeaking, child) {
                        return _VisualActions(
                          isSpeaking: isSpeaking,
                          isFavorite: _isFavorite,
                          onListen: () => unawaited(_speakWord()),
                          onFavorite: () => unawaited(_toggleFavorite()),
                        );
                      },
                    ),
                    const SizedBox(height: 28),
                    _DifficultySection(
                      selectedDifficulty: _selectedDifficulty,
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

class _FlippableWordCard extends StatelessWidget {
  const _FlippableWordCard({
    required this.animation,
    required this.onTap,
    required this.word,
  });

  final Animation<double> animation;
  final VoidCallback onTap;
  final Word word;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final angle = animation.value * math.pi;
        final showBack = angle >= math.pi / 2;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          child: Card(
            key: const ValueKey('word-card'),
            clipBehavior: Clip.antiAlias,
            color: Theme.of(context).colorScheme.primaryContainer,
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 360),
                child: showBack
                    ? Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.rotationY(math.pi),
                        child: _CardBack(word: word),
                      )
                    : _CardFront(word: word),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CardFront extends StatelessWidget {
  const _CardFront({required this.word});

  final Word word;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(word.emoji, style: const TextStyle(fontSize: 80)),
          const SizedBox(height: 20),
          Text(
            word.english.toUpperCase(),
            style: textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Kartı çevirmek için dokun',
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack({required this.word});

  final Word word;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            toTurkishUpperCase(word.turkish),
            textAlign: TextAlign.center,
            style: textTheme.displaySmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            word.exampleSentence,
            textAlign: TextAlign.center,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            word.exampleTranslation,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _VisualActions extends StatelessWidget {
  const _VisualActions({
    required this.isSpeaking,
    required this.isFavorite,
    required this.onListen,
    required this.onFavorite,
  });

  final bool isSpeaking;
  final bool isFavorite;
  final VoidCallback onListen;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isSpeaking ? null : onListen,
            icon: isSpeaking
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.volume_up_rounded),
            label: Text(isSpeaking ? 'Dinleniyor' : 'Dinle'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onFavorite,
            icon: Icon(
              isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
            ),
            label: const Text('Favori'),
          ),
        ),
      ],
    );
  }
}

class _DifficultySection extends StatelessWidget {
  const _DifficultySection({
    required this.selectedDifficulty,
    required this.enabled,
    required this.onSelected,
  });

  final _LearningRating? selectedDifficulty;
  final bool enabled;
  final ValueChanged<_LearningRating> onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bu kelime nasıldı?',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final rating in _LearningRating.values)
              ChoiceChip(
                label: Text(rating.label),
                selected: selectedDifficulty == rating,
                onSelected: enabled ? (_) => onSelected(rating) : null,
              ),
          ],
        ),
      ],
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
