import 'dart:math' as math;

import 'package:flutter/material.dart';

class WordCardScreen extends StatefulWidget {
  const WordCardScreen({super.key});

  @override
  State<WordCardScreen> createState() => _WordCardScreenState();
}

class _WordCardScreenState extends State<WordCardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;
  String? _selectedDifficulty;

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Hayvanlar'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 24),
            child: Center(child: Text('1 / 24')),
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
                    ),
                    const SizedBox(height: 20),
                    const _VisualActions(),
                    const SizedBox(height: 28),
                    _DifficultySection(
                      selectedDifficulty: _selectedDifficulty,
                      onSelected: (difficulty) {
                        setState(() => _selectedDifficulty = difficulty);
                      },
                    ),
                    const SizedBox(height: 28),
                    const _WordNavigation(),
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
  const _FlippableWordCard({required this.animation, required this.onTap});

  final Animation<double> animation;
  final VoidCallback onTap;

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
                        child: const _CardBack(),
                      )
                    : const _CardFront(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CardFront extends StatelessWidget {
  const _CardFront();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🐶', style: TextStyle(fontSize: 80)),
          const SizedBox(height: 20),
          Text(
            'DOG',
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
  const _CardBack();

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
            'KÖPEK',
            textAlign: TextAlign.center,
            style: textTheme.displaySmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'The dog is sleeping.',
            textAlign: TextAlign.center,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Köpek uyuyor.',
            textAlign: TextAlign.center,
            style: textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _VisualActions extends StatelessWidget {
  const _VisualActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.volume_up_rounded),
            label: const Text('Dinle'),
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
  const _WordNavigation();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Önceki'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Sonraki'),
          ),
        ),
      ],
    );
  }
}
