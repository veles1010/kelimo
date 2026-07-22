import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kelimo/models/word.dart';
import 'package:kelimo/services/learning_engine.dart';
import 'package:kelimo/utils/turkish_case.dart';
import 'package:kelimo/widgets/scale_down_single_line_text.dart';
import 'package:kelimo/widgets/glass_surface.dart';

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
        final colorScheme = Theme.of(context).colorScheme;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          child: GlassSurface(
            enableBlur: false,
            borderRadius: BorderRadius.circular(24),
            padding: EdgeInsets.zero,
            child: Card(
              key: const ValueKey('word-card'),
              clipBehavior: Clip.antiAlias,
              color: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primaryContainer,
                      colorScheme.surfaceContainerHigh,
                    ],
                  ),
                ),
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
          child: GlassSurface(
            enableBlur: false,
            showShadow: false,
            borderRadius: BorderRadius.circular(16),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(side: BorderSide.none),
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
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GlassSurface(
            enableBlur: false,
            showShadow: false,
            borderRadius: BorderRadius.circular(16),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(side: BorderSide.none),
              onPressed: enabled ? onFavorite : null,
              icon: Icon(
                isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
              ),
              label: const Text('Favori'),
            ),
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
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final controlHeight = 52.0 + ((textScale - 1).clamp(0.0, 0.5) * 32);

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
        Row(
          children: [
            for (final (index, rating) in LearningRating.values.indexed) ...[
              if (index > 0) const SizedBox(width: 10),
              Expanded(
                child: _RatingButton(
                  rating: rating,
                  selected: selectedRating == rating,
                  enabled: enabled,
                  minHeight: controlHeight,
                  onTap: () => onSelected(rating),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _RatingButton extends StatelessWidget {
  const _RatingButton({
    required this.rating,
    required this.selected,
    required this.enabled,
    required this.minHeight,
    required this.onTap,
  });

  final LearningRating rating;
  final bool selected;
  final bool enabled;
  final double minHeight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = switch (rating) {
      LearningRating.easy => colorScheme.primary,
      LearningRating.again => colorScheme.secondary,
      LearningRating.hard => colorScheme.error,
    };
    final icon = switch ((rating, selected)) {
      (LearningRating.easy, false) => Icons.check_circle_outline_rounded,
      (LearningRating.easy, true) => Icons.check_circle_rounded,
      (LearningRating.again, false) => Icons.replay_rounded,
      (LearningRating.again, true) => Icons.replay_circle_filled_rounded,
      (LearningRating.hard, false) => Icons.warning_amber_rounded,
      (LearningRating.hard, true) => Icons.error_rounded,
    };
    final foreground = enabled
        ? (selected ? accent : colorScheme.onSurface)
        : colorScheme.onSurface.withValues(alpha: 0.38);
    const radius = BorderRadius.all(Radius.circular(999));

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: learningRatingLabel(rating),
      child: GlassSurface(
        key: ValueKey('learning-rating-${rating.name}'),
        enableBlur: false,
        showShadow: false,
        borderRadius: radius,
        padding: EdgeInsets.zero,
        child: Material(
          color: selected ? accent.withValues(alpha: 0.2) : Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: enabled ? onTap : null,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 104;
                  final label = Text(
                    learningRatingLabel(rating),
                    maxLines: compact ? 2 : 1,
                    overflow: TextOverflow.visible,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                  final iconWidget = Icon(icon, size: 19, color: foreground);

                  return Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 6 : 10,
                      vertical: 6,
                    ),
                    child: compact
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              iconWidget,
                              const SizedBox(height: 2),
                              label,
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              iconWidget,
                              const SizedBox(width: 5),
                              Flexible(child: label),
                            ],
                          ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
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
