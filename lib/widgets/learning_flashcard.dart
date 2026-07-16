import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kelimo/models/word.dart';
import 'package:kelimo/services/learning_engine.dart';
import 'package:kelimo/utils/turkish_case.dart';
import 'package:kelimo/widgets/scale_down_single_line_text.dart';

class LearningFlashcard extends StatelessWidget {
  const LearningFlashcard({
    required this.animation,
    required this.onTap,
    required this.word,
    super.key,
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

class LearningWordActions extends StatelessWidget {
  const LearningWordActions({
    required this.isSpeaking,
    required this.isFavorite,
    required this.onListen,
    required this.onFavorite,
    this.enabled = true,
    super.key,
  });

  final bool isSpeaking;
  final bool isFavorite;
  final bool enabled;
  final VoidCallback onListen;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: enabled && !isSpeaking ? onListen : null,
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
            onPressed: enabled ? onFavorite : null,
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

class LearningRatingSection extends StatelessWidget {
  const LearningRatingSection({
    required this.selectedRating,
    required this.enabled,
    required this.onSelected,
    super.key,
  });

  final LearningRating? selectedRating;
  final bool enabled;
  final ValueChanged<LearningRating> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bu kelime nasıldı?',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final rating in LearningRating.values)
              ChoiceChip(
                key: ValueKey('learning-rating-${rating.name}'),
                label: Text(learningRatingLabel(rating)),
                selected: selectedRating == rating,
                onSelected: enabled ? (_) => onSelected(rating) : null,
              ),
          ],
        ),
      ],
    );
  }
}

String learningRatingLabel(LearningRating rating) {
  return switch (rating) {
    LearningRating.easy => 'Kolay',
    LearningRating.again => 'Tekrar Et',
    LearningRating.hard => 'Zor',
  };
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
          ScaleDownSingleLineText(
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
          ScaleDownSingleLineText(
            toTurkishUpperCase(word.turkish),
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
