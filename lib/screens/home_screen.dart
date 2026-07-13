import 'package:flutter/material.dart';
import 'package:kelimo/screens/animals_category_screen.dart';
import 'package:kelimo/theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columnCount = constraints.maxWidth >= 700 ? 2 : 1;

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 960),
                        child: const _HeaderAndProgress(),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 960),
                        child: Text(
                          'Kategoriler',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final gridWidth = constraints.crossAxisExtent.clamp(
                        0.0,
                        960.0,
                      );

                      return SliverPadding(
                        padding: EdgeInsets.symmetric(
                          horizontal:
                              (constraints.crossAxisExtent - gridWidth) / 2,
                        ),
                        sliver: SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columnCount,
                                mainAxisExtent: 164,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                          delegate: SliverChildListDelegate.fixed([
                            _CategoryCard(
                              icon: '🐶',
                              name: 'Hayvanlar',
                              wordCount: 24,
                              progress: 0.75,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        const AnimalsCategoryScreen(),
                                  ),
                                );
                              },
                            ),
                            const _CategoryCard(
                              icon: '🍎',
                              name: 'Yiyecekler',
                              wordCount: 20,
                              progress: 0.45,
                            ),
                            const _CategoryCard(
                              icon: '🎨',
                              name: 'Renkler',
                              wordCount: 16,
                              progress: 0.60,
                            ),
                            const _CategoryCard(
                              icon: '🏠',
                              name: 'Ev',
                              wordCount: 22,
                              progress: 0.30,
                            ),
                            const _CategoryCard(
                              icon: '👨‍👩‍👧',
                              name: 'Aile',
                              wordCount: 18,
                              progress: 0.50,
                            ),
                            const _CategoryCard(
                              icon: '🚌',
                              name: 'Ulaşım',
                              wordCount: 20,
                              progress: 0.20,
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Ana Sayfa',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school_rounded),
            label: 'Öğren',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'İlerleme',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Ayarlar',
          ),
        ],
      ),
    );
  }
}

class _HeaderAndProgress extends StatelessWidget {
  const _HeaderAndProgress();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Merhaba!',
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text('Bugün öğrenmeye hazır mısın?', style: textTheme.titleMedium),
        const SizedBox(height: 24),
        const _DailyProgressCard(),
        const SizedBox(height: 16),
        const _LevelCard(),
        const SizedBox(height: 16),
        const _DailyOverviewCards(),
      ],
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard();

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
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Seviye 4',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text('Bir sonraki seviyeye doğru'),
                    ],
                  ),
                ),
                Text(
                  '720 / 1000 XP',
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: 0.72,
              minHeight: 10,
              borderRadius: BorderRadius.circular(5),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyOverviewCards extends StatelessWidget {
  const _DailyOverviewCards();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;
        final cardWidth = isWide
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(width: cardWidth, child: const _DailyStreakCard()),
            SizedBox(width: cardWidth, child: const _DailyTaskCard()),
          ],
        );
      },
    );
  }
}

class _DailyStreakCard extends StatelessWidget {
  const _DailyStreakCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: AppDimensions.cardPadding,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.local_fire_department_rounded,
                color: colorScheme.secondary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Günlük Seri',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '7 gün',
                    style: textTheme.titleLarge?.copyWith(
                      color: colorScheme.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyTaskCard extends StatelessWidget {
  const _DailyTaskCard();

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
            Row(
              children: [
                Icon(Icons.task_alt_rounded, color: colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Günlük Görev',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '6 / 10',
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text('Bugün 10 kelime öğren'),
            const SizedBox(height: 10),
            const LinearProgressIndicator(value: 0.60),
          ],
        ),
      ),
    );
  }
}

class _DailyProgressCard extends StatelessWidget {
  const _DailyProgressCard();

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
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Günlük ilerleme',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '18 / 30 kelime',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const LinearProgressIndicator(value: 0.60),
            const SizedBox(height: 16),
            Text(
              '🔥 7 günlük seri',
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.icon,
    required this.name,
    required this.wordCount,
    required this.progress,
    this.onTap,
  });

  final String icon;
  final String name;
  final int wordCount;
  final double progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final percentage = (progress * 100).round();

    final content = Padding(
      padding: AppDimensions.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(icon, style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('$wordCount kelime'),
                  ],
                ),
              ),
              Text(
                '%$percentage',
                style: textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Spacer(),
          LinearProgressIndicator(value: progress),
        ],
      ),
    );

    return Card(
      clipBehavior: onTap == null ? Clip.none : Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}
