import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kelimo/models/learning_category.dart';
import 'package:kelimo/models/word.dart';
import 'package:kelimo/repositories/word_progress_repository.dart';
import 'package:kelimo/repositories/quiz_repository.dart';
import 'package:kelimo/screens/category_quiz_screen.dart';
import 'package:kelimo/services/english_tts_service.dart';
import 'package:kelimo/services/achievement_service.dart';
import 'package:kelimo/services/daily_reminder_service.dart';
import 'package:kelimo/services/learning_engine.dart';
import 'package:kelimo/services/settings_service.dart';
import 'package:kelimo/services/streak_service.dart';
import 'package:kelimo/services/xp_service.dart';
import 'package:kelimo/widgets/learning_flashcard.dart';
import 'package:kelimo/widgets/achievement_notification.dart';
import 'package:kelimo/widgets/glass_surface.dart';
import 'package:kelimo/services/category_access_service.dart';
import 'package:kelimo/services/banner_ad_service.dart';
import 'package:kelimo/services/interstitial_ad_service.dart';

/// Distinguishes a normal category lesson from a manually opened word.
enum WordLearningSessionType { normalLesson, manualWord }

class WordCardScreen extends StatefulWidget {
  WordCardScreen({
    required this.category,
    required this.wordProgressStore,
    required this.xpService,
    super.key,
    this.ttsService,
    this.streakService,
    this.initialWordIndex = 0,
    this.initialWordId,
    this.settingsService,
    this.achievementService,
    this.dailyReminderService,
    this.categoryAccessService,
    this.interstitialAdService,
    this.bannerAdService,
    this.quizStore,
    this.sessionType = WordLearningSessionType.manualWord,
  }) : assert(
         initialWordIndex >= 0 && initialWordIndex < category.words.length,
       );

  final LearningCategory category;
  final WordProgressStore wordProgressStore;
  final XpService xpService;
  final EnglishTtsService? ttsService;
  final StreakService? streakService;
  final int initialWordIndex;

  /// Lets a learner manually revisit a known word from a filtered list.
  /// Automatic category sessions intentionally omit known words.
  final String? initialWordId;
  final SettingsService? settingsService;
  final AchievementService? achievementService;
  final DailyReminderService? dailyReminderService;
  final CategoryAccessService? categoryAccessService;
  final InterstitialAdService? interstitialAdService;
  final BannerAdService? bannerAdService;
  final QuizStore? quizStore;
  final WordLearningSessionType sessionType;

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
  late final BannerAdService? _bannerAdService;
  late final bool _ownsBannerAdService;
  late final bool _allWordsKnown;
  LearningRating? _selectedDifficulty;
  bool _isEvaluating = false;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _ttsService =
        widget.ttsService ??
        EnglishTtsService(settingsService: widget.settingsService);
    final requestedWordId =
        widget.initialWordId ??
        widget.category.words[widget.initialWordIndex].id;
    final availableWords = widget.category.words
        .where(
          (word) =>
              !widget.wordProgressStore.progressFor(word.id).isKnown ||
              word.id == widget.initialWordId,
        )
        .toList(growable: false);
    _allWordsKnown = availableWords.isEmpty;
    final List<Word> sessionWords = _allWordsKnown
        ? <Word>[widget.category.words.first]
        : availableWords;
    final sessionIndex = sessionWords.indexWhere(
      (word) => word.id == requestedWordId,
    );
    _learningEngine = LearningEngine(
      sessionWords,
      initialWordIndex: sessionIndex < 0 ? 0 : sessionIndex,
    );
    _ownsStreakService = widget.streakService == null;
    _streakService = widget.streakService ?? StreakService();
    final isNormalLesson =
        widget.sessionType == WordLearningSessionType.normalLesson;
    _ownsBannerAdService = isNormalLesson && widget.bannerAdService == null;
    _bannerAdService = isNormalLesson
        ? (widget.bannerAdService ??
              (widget.interstitialAdService == null
                  ? null
                  : GoogleBannerAdService(
                      widget.interstitialAdService!,
                      placement: BannerPlacement.learning,
                    )))
        : null;
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
    if (_ownsBannerAdService) _bannerAdService?.dispose();
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
      if (!_learningEngine.isComplete) _syncFavoriteState();
    });
  }

  void _showPreviousWord() {
    if (!_learningEngine.canPrevious || _isEvaluating) return;

    unawaited(_ttsService.stop());
    _flipController.reset();
    setState(() {
      _learningEngine.previousWord();
      _selectedDifficulty = null;
      if (!_learningEngine.isComplete) _syncFavoriteState();
    });
  }

  Future<void> _evaluateWord(LearningRating rating) async {
    if (_isEvaluating || _learningEngine.isComplete) return;

    setState(() {
      _selectedDifficulty = rating;
      _isEvaluating = true;
    });
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
      if (!_learningEngine.isComplete) _syncFavoriteState();
    });

    var progressSaved = false;
    var completedDailyGoal = false;
    try {
      await widget.wordProgressStore.saveLearningResult(learningResult);
      progressSaved = true;
      completedDailyGoal = await _streakService.recordEvaluation();
      final xpSaved = await widget.xpService.awardWordReview(
        wordId: learningResult.word.id,
        rating: learningResult.rating,
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
    if (progressSaved) await widget.dailyReminderService?.refreshSchedule();
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
    final access = widget.categoryAccessService;
    if (access != null && !access.canOpen(widget.category)) {
      return const Scaffold(
        body: Center(child: Text('Bu kategori henüz kilitli.')),
      );
    }
    if (_allWordsKnown || _learningEngine.isComplete) {
      return _buildCategoryCompletedScreen(context);
    }
    final word = _learningEngine.currentWord;
    const bottomPadding = 32.0;

    Widget buildLearningBody(bool bannerLoaded) {
      return SafeArea(
        top: false,
        // The list owns the system inset until a loaded banner takes that
        // position. This keeps controls reachable in either state.
        bottom: !bannerLoaded,
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // The constraints here already exclude the loaded banner.
                  // Keep normal screens roomy, while giving standard phones
                  // enough room to show every control above a tall iOS ad.
                  final compact = bannerLoaded && constraints.maxHeight < 720;
                  final cardMinHeight = compact
                      ? 250.0
                      : MediaQuery.sizeOf(context).height < 680
                      ? 280.0
                      : 360.0;
                  final primaryGap = compact ? 10.0 : 20.0;
                  final sectionGap = compact ? 14.0 : 28.0;

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      12,
                      20,
                      bottomPadding,
                    ),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 680),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ValueListenableBuilder<bool>(
                                valueListenable: _ttsService.isSpeaking,
                                builder: (context, isSpeaking, child) {
                                  return LearningFlashcard(
                                    animation: _flipAnimation,
                                    onTap: _flipCard,
                                    word: word,
                                    minHeight: cardMinHeight,
                                    isSpeakingExample: isSpeaking,
                                    onSpeakExample: () =>
                                        unawaited(_speakExampleSentence()),
                                  );
                                },
                              ),
                              SizedBox(height: primaryGap),
                              ValueListenableBuilder<bool>(
                                valueListenable: _ttsService.isSpeaking,
                                builder: (context, isSpeaking, child) {
                                  return LearningWordActions(
                                    isSpeaking: isSpeaking,
                                    isFavorite: _isFavorite,
                                    onListen: () => unawaited(_speakWord()),
                                    onFavorite: () =>
                                        unawaited(_toggleFavorite()),
                                  );
                                },
                              ),
                              SizedBox(height: sectionGap),
                              LearningRatingSection(
                                selectedRating: _selectedDifficulty,
                                enabled:
                                    !_isEvaluating &&
                                    !_learningEngine.isComplete,
                                onSelected: (rating) =>
                                    unawaited(_evaluateWord(rating)),
                              ),
                              SizedBox(height: sectionGap),
                              _WordNavigation(
                                onPrevious:
                                    !_learningEngine.canPrevious ||
                                        _isEvaluating
                                    ? null
                                    : _showPreviousWord,
                                onNext:
                                    !_learningEngine.canNext || _isEvaluating
                                    ? null
                                    : _showNextWord,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            if (_bannerAdService != null)
              LearningBannerSlot(
                key: const ValueKey('learning-banner-slot'),
                service: _bannerAdService,
              ),
          ],
        ),
      );
    }

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
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
        body: _bannerAdService == null
            ? buildLearningBody(false)
            : AnimatedBuilder(
                animation: _bannerAdService,
                builder: (context, child) =>
                    buildLearningBody(_bannerAdService.isLoaded),
              ),
      ),
    );
  }

  Widget _buildCategoryCompletedScreen(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: const BackButton(),
          title: Text(widget.category.title),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: GlassSurface(
                borderRadius: BorderRadius.circular(28),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.celebration_rounded,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Kategori Tamamlandı',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${widget.category.title} kategorisindeki tüm kelimeleri '
                        'tamamladın. Şimdi öğrendiklerini quiz ile pekiştirebilirsin.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      if (widget.quizStore != null) ...[
                        FilledButton(
                          onPressed: _openCategoryQuiz,
                          child: Text('${widget.category.title} Quizini Çöz'),
                        ),
                        const SizedBox(height: 10),
                      ],
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Kategoriye Dön'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _speakExampleSentence() async {
    final sentence = _learningEngine.currentWord.exampleSentence;
    if (sentence.trim().isEmpty) return;
    final didSpeak = await _ttsService.speak(sentence);
    if (!didSpeak && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ses oynatılamadı')));
    }
  }

  void _openCategoryQuiz() {
    final quizStore = widget.quizStore;
    if (quizStore == null) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => CategoryQuizScreen(
          category: widget.category,
          quizStore: quizStore,
          xpService: widget.xpService,
          achievementService: widget.achievementService,
          interstitialAdService: widget.interstitialAdService,
          streakService: widget.streakService,
          categoryAccessService: widget.categoryAccessService,
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
      key: const ValueKey('word-navigation'),
      children: [
        Expanded(
          child: GlassSurface(
            enableBlur: false,
            showShadow: false,
            borderRadius: BorderRadius.circular(16),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(side: BorderSide.none),
              onPressed: onPrevious,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Önceki'),
            ),
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
