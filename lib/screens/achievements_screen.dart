import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kelimo/data/achievement_catalog.dart';
import 'package:kelimo/models/achievement.dart';
import 'package:kelimo/services/achievement_service.dart';
import 'package:kelimo/theme/app_theme.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({required this.service, super.key});

  final AchievementService service;

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    try {
      await widget.service.evaluate();
    } catch (_) {
      // Kalıcı veri hatası mevcut rozet görünümünü kullanılamaz yapmamalı.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Başarımlar'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: AnimatedBuilder(
        animation: widget.service,
        builder: (context, child) {
          final service = widget.service;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SummaryCard(service: service),
                      const SizedBox(height: 20),
                      for (final achievement
                          in AchievementCatalog.achievements) ...[
                        _AchievementCard(
                          achievement: achievement,
                          metrics: service.metrics,
                          unlock: service.unlockFor(achievement.id),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.service});

  final AchievementService service;

  @override
  Widget build(BuildContext context) {
    final total = AchievementCatalog.achievements.length;
    final unlocked = service.unlockedCount;
    final message = unlocked == 0
        ? 'İlk rozetin seni bekliyor.'
        : unlocked == total
        ? 'Tüm başarımları tamamladın!'
        : 'Yeni rozetler için çalışmaya devam et.';
    return Card(
      child: Padding(
        padding: AppDimensions.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Açılan rozet',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              '$unlocked / $total',
              key: const ValueKey('achievement-summary-count'),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: total == 0 ? 0 : unlocked / total),
            const SizedBox(height: 10),
            Text(message),
          ],
        ),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({
    required this.achievement,
    required this.metrics,
    required this.unlock,
  });

  final Achievement achievement;
  final AchievementMetrics metrics;
  final AchievementUnlock? unlock;

  @override
  Widget build(BuildContext context) {
    final isUnlocked = unlock != null;
    final progress = achievement.progress(metrics).clamp(0, achievement.target);
    return Opacity(
      opacity: isUnlocked ? 1 : 0.68,
      child: Card(
        key: ValueKey('achievement-${achievement.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(achievement.emoji, style: const TextStyle(fontSize: 38)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            achievement.title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Icon(
                          isUnlocked
                              ? Icons.verified_rounded
                              : Icons.lock_outline_rounded,
                          color: isUnlocked
                              ? Theme.of(context).colorScheme.secondary
                              : Theme.of(context).colorScheme.outline,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(achievement.description),
                    const SizedBox(height: 10),
                    if (isUnlocked) ...[
                      Text(
                        'Kazanıldı • ${formatAchievementDate(unlock!.unlockedAt)}',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ] else ...[
                      Text('$progress / ${achievement.target}'),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: achievement.target == 0
                            ? 0
                            : progress / achievement.target,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String formatAchievementDate(DateTime date) {
  const months = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];
  final local = date.toLocal();
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}
