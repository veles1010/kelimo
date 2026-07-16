import 'package:flutter/material.dart';
import 'package:kelimo/models/achievement.dart';

Future<void> showAchievementNotifications(
  BuildContext context,
  List<Achievement> achievements,
) async {
  for (final achievement in achievements) {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: Text(achievement.emoji, style: const TextStyle(fontSize: 52)),
        title: const Text('Yeni başarım!', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              achievement.title,
              textAlign: TextAlign.center,
              style: Theme.of(
                dialogContext,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(achievement.description, textAlign: TextAlign.center),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Harika!'),
          ),
        ],
      ),
    );
  }
}
