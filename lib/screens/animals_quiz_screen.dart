import 'package:flutter/material.dart';
import 'package:kelimo/data/animal_words.dart';
import 'package:kelimo/models/word.dart';
import 'package:kelimo/screens/quiz_result_screen.dart';
import 'package:kelimo/theme/app_theme.dart';

class AnimalsQuizScreen extends StatefulWidget {
  const AnimalsQuizScreen({super.key});

  @override
  State<AnimalsQuizScreen> createState() => _AnimalsQuizScreenState();
}

class _AnimalsQuizScreenState extends State<AnimalsQuizScreen> {
  static const _questionCount = 10;

  int _questionIndex = 0;
  int _correctAnswerCount = 0;
  String? _selectedAnswer;

  Word get _currentWord => animalWords[_questionIndex];

  List<String> _optionsFor(int index) {
    final options = [
      animalWords[index].turkish,
      animalWords[(index + 1) % animalWords.length].turkish,
      animalWords[(index + 8) % animalWords.length].turkish,
      animalWords[(index + 15) % animalWords.length].turkish,
    ];
    final shift = (index + 1) % options.length;

    return [...options.skip(shift), ...options.take(shift)];
  }

  void _selectAnswer(String answer) {
    if (_selectedAnswer != null) return;
    setState(() {
      _selectedAnswer = answer;
      if (answer == _currentWord.turkish) {
        _correctAnswerCount++;
      }
    });
  }

  void _continueQuiz() {
    if (_selectedAnswer == null) return;

    if (_questionIndex == _questionCount - 1) {
      _showResult();
      return;
    }

    setState(() {
      _questionIndex++;
      _selectedAnswer = null;
    });
  }

  void _showResult() {
    final navigator = Navigator.of(context);

    navigator.pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => QuizResultScreen(
          categoryName: 'Hayvanlar',
          correctAnswerCount: _correctAnswerCount,
          totalQuestionCount: _questionCount,
          successPercentage: calculateQuizPercentage(
            correct: _correctAnswerCount,
            total: _questionCount,
          ),
          onRetry: () {
            navigator.pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => const AnimalsQuizScreen(),
              ),
            );
          },
          onReturnToCategory: navigator.pop,
          onReturnHome: () => navigator.popUntil((route) => route.isFirst),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = _optionsFor(_questionIndex);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Hayvanlar Quiz'),
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
                      onPressed: _selectedAnswer == null ? null : _continueQuiz,
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
            Text(
              word.english.toUpperCase(),
              textAlign: TextAlign.center,
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
