import 'package:flutter/material.dart';
import 'package:kelimo/screens/word_card_screen.dart';
import 'package:kelimo/theme/app_theme.dart';

class AnimalsCategoryScreen extends StatelessWidget {
  const AnimalsCategoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _CategoryHeader(),
                    const SizedBox(height: 24),
                    const _CategoryProgressCard(),
                    const SizedBox(height: 24),
                    _ActionCard(
                      icon: Icons.school_rounded,
                      title: 'Öğrenmeye Başla',
                      subtitle: 'Kelime kartlarıyla çalış',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const WordCardScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    const _ActionCard(
                      icon: Icons.quiz_rounded,
                      title: 'Quiz Çöz',
                      subtitle: 'Bilgini test et',
                    ),
                    const SizedBox(height: 12),
                    const _ActionCard(
                      icon: Icons.insights_rounded,
                      title: 'İstatistik',
                      subtitle: 'Kategori performansını gör',
                    ),
                    const SizedBox(height: 32),
                    const _RecentStudies(),
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

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          ),
          child: const Text('🐶', style: TextStyle(fontSize: 36)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hayvanlar',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text('24 kelime', style: textTheme.titleMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryProgressCard extends StatelessWidget {
  const _CategoryProgressCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: AppDimensions.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kategori ilerlemesi',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '12 / 24 kelime',
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 18),
            LinearProgressIndicator(
              value: 0.50,
              minHeight: 12,
              borderRadius: BorderRadius.circular(6),
            ),
            const SizedBox(height: 12),
            Text(
              '%50 tamamlandı',
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final content = Padding(
      padding: AppDimensions.cardPadding,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle),
              ],
            ),
          ),
        ],
      ),
    );

    return Card(
      clipBehavior: onTap == null ? Clip.none : Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

class _RecentStudies extends StatelessWidget {
  const _RecentStudies();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Son çalışmalar',
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: AppDimensions.cardPadding,
            child: Column(
              children: [
                _WordRow(english: 'Dog', turkish: 'Köpek'),
                Divider(height: 24),
                _WordRow(english: 'Cat', turkish: 'Kedi'),
                Divider(height: 24),
                _WordRow(english: 'Bird', turkish: 'Kuş'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WordRow extends StatelessWidget {
  const _WordRow({required this.english, required this.turkish});

  final String english;
  final String turkish;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            english,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Text(turkish, style: textTheme.titleMedium),
      ],
    );
  }
}
