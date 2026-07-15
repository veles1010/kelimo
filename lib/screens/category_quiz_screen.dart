import 'package:flutter/material.dart';
import 'package:kelimo/models/learning_category.dart';
import 'package:kelimo/models/word.dart';
import 'package:kelimo/repositories/quiz_repository.dart';
import 'package:kelimo/screens/quiz_result_screen.dart';
import 'package:kelimo/services/xp_service.dart';
import 'package:kelimo/theme/app_theme.dart';
import 'package:kelimo/widgets/scale_down_single_line_text.dart';

class CategoryQuizScreen extends StatefulWidget {
  CategoryQuizScreen({
    required this.category,
    required this.quizStore,
    required this.xpService,
    DateTime Function()? now,
    super.key,
  }) : now = now ?? DateTime.now,
       assert(category.words.length >= 4);

  final LearningCategory category;
  final QuizStore quizStore;
  final XpService xpService;
  final DateTime Function() now;

  @override
  State<CategoryQuizScreen> createState() => _CategoryQuizScreenState();
}

class QuizCorrectStreakCounter {
  int _current = 0;
  int _longest = 0;

  int get current => _current;
  int get longest => _longest;

  void recordAnswer({required bool isCorrect}) {
    if (!isCorrect) {
      _current = 0;
      return;
    }

    _current++;
    if (_current > _longest) {
      _longest = _current;
    }
  }
}

class _CategoryQuizScreenState extends State<CategoryQuizScreen> {
  int _questionIndex = 0;
  int _correctAnswerCount = 0;
  String? _selectedAnswer;
  bool _isCompleting = false;
  final QuizCorrectStreakCounter _correctStreak = QuizCorrectStreakCounter();
  late final DateTime _startedAt;
  Duration? _elapsedDuration;

  @override
  void initState() {
    super.initState();
    _startedAt = widget.now();
  }

  int get _questionCount =>
      widget.category.words.length < 10 ? widget.category.words.length : 10;

  Word get _currentWord => widget.category.words[_questionIndex];

  List<String> _optionsFor(int index) {
    final words = widget.category.words;
    final distinctOptions = <String>{words[index].turkish};
    var offset = 1;
    while (distinctOptions.length < 4 && offset < words.length) {
      distinctOptions.add(words[(index + offset) % words.length].turkish);
      offset++;
    }
    final options = distinctOptions.toList(growable: false);
    final shift = (index + 1) % options.length;

    return [...options.skip(shift), ...options.take(shift)];
  }

  void _selectAnswer(String answer) {
    if (_selectedAnswer != null) return;
    setState(() {
      _selectedAnswer = answer;
      final isCorrect = answer == _currentWord.turkish;
      _correctStreak.recordAnswer(isCorrect: isCorrect);
      if (isCorrect) {
        _correctAnswerCount++;
      }
      if (_questionIndex == _questionCount - 1) {
        _elapsedDuration = _durationSinceStart();
      }
    });
  }

  Duration _durationSinceStart() {
    final duration = widget.now().difference(_startedAt);
    return duration.isNegative ? Duration.zero : duration;
  }

  void _continueQuiz() {
    if (_selectedAnswer == null || _isCompleting) return;

    if (_questionIndex == _questionCount - 1) {
      _showResult();
      return;
    }

    setState(() {
      _questionIndex++;
      _selectedAnswer = null;
    });
  }

  Future<void> _showResult() async {
    if (_isCompleting) return;
    final navigator = Navigator.of(context);
    final elapsedDuration = _elapsedDuration ?? _durationSinceStart();
    final successPercentage = calculateQuizPercentage(
      correct: _correctAnswerCount,
      total: _questionCount,
    );
    setState(() => _isCompleting = true);

    try {
      final completion = await widget.quizStore.saveCompletedQuiz(
        categoryId: widget.category.id,
        correctCount: _correctAnswerCount,
        totalQuestions: _questionCount,
        scorePercent: successPercentage,
      );
      widget.xpService.applyPersistedState(completion.xpState);
      if (!mounted) return;

      navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => QuizResultScreen(
            categoryName: widget.category.title,
            correctAnswerCount: _correctAnswerCount,
            totalQuestionCount: _questionCount,
            successPercentage: successPercentage,
            xpAwarded: completion.attempt.xpAwarded,
            longestCorrectStreak: _correctStreak.longest,
            elapsedDuration: elapsedDuration,
            onRetry: () {
              navigator.pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => CategoryQuizScreen(
                    category: widget.category,
                    quizStore: widget.quizStore,
                    xpService: widget.xpService,
                    now: widget.now,
                  ),
                ),
              );
            },
            onReturnToCategory: navigator.pop,
            onReturnHome: () => navigator.popUntil((route) => route.isFirst),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isCompleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quiz sonucu kaydedilemedi')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _optionsFor(_questionIndex);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text('${widget.category.title} Quiz'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 24),
            child: Center(
              child: Text('Soru ${_questionIndex + 1} / $_questionCount'),
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
                    LinearProgressIndicator(
                      value: (_questionIndex + 1) / _questionCount,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 24),
                    _QuestionCard(word: _currentWord),
                    const SizedBox(height: 20),
                    for (final option in options) ...[
                      _AnswerOption(
                        option: option,
                        correctAnswer: _currentWord.turkish,
                        selectedAnswer: _selectedAnswer,
                        onTap: () => _selectAnswer(option),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _selectedAnswer == null || _isCompleting
                          ? null
                          : _continueQuiz,
                      child: Text(
                        _questionIndex == _questionCount - 1
                            ? 'Sonucu Gör'
                            : 'Sonraki Soru',
                      ),
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

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.word});

  final Word word;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: Column(
          children: [
            Text(word.emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            ScaleDownSingleLineText(
              word.english.toUpperCase(),
              style: textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Doğru Türkçe karşılığı seç',
              textAlign: TextAlign.center,
              style: textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerOption extends StatelessWidget {
  const _AnswerOption({
    required this.option,
    required this.correctAnswer,
    required this.selectedAnswer,
    required this.onTap,
  });

  final String option;
  final String correctAnswer;
  final String? selectedAnswer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAnswered = selectedAnswer != null;
    final isCorrect = option == correctAnswer;
    final isSelected = option == selectedAnswer;
    final showCorrect = isAnswered && isCorrect;
    final showWrong = isAnswered && isSelected && !isCorrect;
    final correctColor = isDark
        ? const Color(0xFF81C784)
        : const Color(0xFF2E7D32);
    final backgroundColor = showCorrect
        ? (isDark ? const Color(0xFF173D25) : const Color(0xFFE2F4E5))
        : showWrong
        ? colorScheme.errorContainer
        : Theme.of(context).cardColor;
    final foregroundColor = showCorrect
        ? correctColor
        : showWrong
        ? colorScheme.onErrorContainer
        : colorScheme.onSurface;
    final borderColor = showCorrect
        ? correctColor
        : showWrong
        ? colorScheme.error
        : colorScheme.outlineVariant;

    return Material(
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
        side: BorderSide(color: borderColor, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('quiz-option-$option'),
        onTap: isAnswered ? null : onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    option,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: foregroundColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (showCorrect)
                  Icon(Icons.check_circle_rounded, color: correctColor),
                if (showWrong)
                  Icon(Icons.cancel_rounded, color: colorScheme.error),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
