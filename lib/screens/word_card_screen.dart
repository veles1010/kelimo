import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kelimo/data/animal_words.dart';
import 'package:kelimo/models/word.dart';
import 'package:kelimo/services/english_tts_service.dart';
import 'package:kelimo/utils/turkish_case.dart';

class WordCardScreen extends StatefulWidget {
  const WordCardScreen({super.key, this.ttsService});

  final EnglishTtsService? ttsService;

  @override
  State<WordCardScreen> createState() => _WordCardScreenState();
}

class _WordCardScreenState extends State<WordCardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;
  late final EnglishTtsService _ttsService;
  int _currentIndex = 0;
  String? _selectedDifficulty;

  @override
  void initState() {
    super.initState();
    _ttsService = widget.ttsService ?? EnglishTtsService();
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

  void _showWord(int index) {
    unawaited(_ttsService.stop());
    _flipController.reset();
    setState(() => _currentIndex = index);
  }

  Future<void> _speakWord() async {
    final didSpeak = await _ttsService.speak(
      animalWords[_currentIndex].english,
    );
    if (!didSpeak && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ses oynatılamadı')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final word = animalWords[_currentIndex];

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
              child: Text('${_currentIndex + 1} / ${animalWords.length}'),
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
                          onListen: () => unawaited(_speakWord()),
                        );
                      },
                    ),
                    const SizedBox(height: 28),
                    _DifficultySection(
                      selectedDifficulty: _selectedDifficulty,
                      onSelected: (difficulty) {
                        setState(() => _selectedDifficulty = difficulty);
                      },
                    ),
                    const SizedBox(height: 28),
                    _WordNavigation(
                      onPrevious: _currentIndex == 0
                          ? null
                          : () => _showWord(_currentIndex - 1),
                      onNext: _currentIndex == animalWords.length - 1
                          ? null
                          : () => _showWord(_currentIndex + 1),
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
  const _VisualActions({required this.isSpeaking, required this.onListen});

  final bool isSpeaking;
  final VoidCallback onListen;

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
            onPressed: () {},
            icon: const Icon(Icons.favorite_border_rounded),
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
    required this.onSelected,
  });

  final String? selectedDifficulty;
  final ValueChanged<String> onSelected;

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
            for (final label in const ['Kolay', 'Tekrar Et', 'Zor'])
              ChoiceChip(
                label: Text(label),
                selected: selectedDifficulty == label,
                onSelected: (_) => onSelected(label),
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
