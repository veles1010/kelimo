import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kelimo/models/app_settings.dart';
import 'package:kelimo/services/data_management_service.dart';
import 'package:kelimo/services/english_tts_service.dart';
import 'package:kelimo/services/settings_service.dart';
import 'package:kelimo/theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.settingsService,
    required this.dataManagementService,
    this.previewTtsService,
    super.key,
  });

  final SettingsService settingsService;
  final DataManagementService dataManagementService;
  final EnglishTtsService? previewTtsService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final EnglishTtsService _ttsService;
  late final bool _ownsTtsService;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _ownsTtsService = widget.previewTtsService == null;
    _ttsService =
        widget.previewTtsService ??
        EnglishTtsService(settingsService: widget.settingsService);
  }

  @override
  void dispose() {
    if (_ownsTtsService) unawaited(_ttsService.dispose());
    super.dispose();
  }

  Future<void> _setDailyGoal(int? value) async {
    if (value == null || _isBusy) return;
    await _run(
      () => widget.settingsService.setDailyGoal(value),
      successMessage: 'Günlük hedef kaydedildi',
    );
  }

  Future<void> _setSpeechRate(SpeechRatePreference? value) async {
    if (value == null || _isBusy) return;
    await _run(
      () => widget.settingsService.setSpeechRate(value),
      successMessage: 'Telaffuz hızı kaydedildi',
    );
  }

  Future<void> _testVoice() async {
    if (_isBusy) return;
    final didSpeak = await _ttsService.speak('Hello, welcome to Kelimo.');
    if (!didSpeak && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ses oynatılamadı')));
    }
  }

  Future<void> _confirmReset({
    required String title,
    required String message,
    required Future<void> Function() action,
    required String successMessage,
  }) async {
    if (_isBusy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sıfırla'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(action, successMessage: successMessage);
  }

  Future<void> _run(
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('İşlem tamamlanamadı')));
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: AnimatedBuilder(
        animation: widget.settingsService,
        builder: (context, child) => ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Ayarlar',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    _Section(
                      title: 'Öğrenme',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonFormField<int>(
                            key: ValueKey(
                              'daily-goal-${widget.settingsService.dailyGoal}',
                            ),
                            initialValue: widget.settingsService.dailyGoal,
                            decoration: const InputDecoration(
                              labelText: 'Günlük kelime hedefi',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final goal in [5, 10, 15, 20])
                                DropdownMenuItem(
                                  value: goal,
                                  child: Text('$goal kelime'),
                                ),
                            ],
                            onChanged: _isBusy
                                ? null
                                : (value) => unawaited(_setDailyGoal(value)),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Yeni hedef bir sonraki günlük çalışmada uygulanır.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _Section(
                      title: 'Ses',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonFormField<SpeechRatePreference>(
                            key: ValueKey(
                              'speech-rate-${widget.settingsService.speechRate.storageValue}',
                            ),
                            initialValue: widget.settingsService.speechRate,
                            decoration: const InputDecoration(
                              labelText: 'Telaffuz hızı',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final rate in SpeechRatePreference.values)
                                DropdownMenuItem(
                                  value: rate,
                                  child: Text(rate.label),
                                ),
                            ],
                            onChanged: _isBusy
                                ? null
                                : (value) => unawaited(_setSpeechRate(value)),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _isBusy
                                ? null
                                : () => unawaited(_testVoice()),
                            icon: const Icon(Icons.volume_up_rounded),
                            label: const Text('Sesi dene'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _Section(
                      title: 'Veri Yönetimi',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          OutlinedButton(
                            onPressed: _isBusy
                                ? null
                                : () => unawaited(
                                    _confirmReset(
                                      title: 'Tercihleri sıfırla',
                                      message:
                                          'Günlük hedef ve telaffuz hızı '
                                          'varsayılan değerlere dönecek. '
                                          'Öğrenme verilerin korunacak.',
                                      action: widget
                                          .settingsService
                                          .resetToDefaults,
                                      successMessage:
                                          'Tercihler varsayılana döndürüldü',
                                    ),
                                  ),
                            child: const Text('Tercihleri varsayılana döndür'),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.error,
                            ),
                            onPressed: _isBusy
                                ? null
                                : () => unawaited(
                                    _confirmReset(
                                      title: 'Öğrenme verilerini sıfırla',
                                      message:
                                          'Favoriler, kelime ilerlemesi, quiz '
                                          'geçmişi, XP ve seri bilgileri kalıcı '
                                          'olarak silinecek. Ayarların korunacak.',
                                      action: widget
                                          .dataManagementService
                                          .resetLearningData,
                                      successMessage:
                                          'Öğrenme verileri sıfırlandı',
                                    ),
                                  ),
                            child: const Text('Öğrenme verilerini sıfırla'),
                          ),
                          const SizedBox(height: 10),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.error,
                            ),
                            onPressed: _isBusy
                                ? null
                                : () => unawaited(
                                    _confirmReset(
                                      title: 'Tüm verileri sıfırla',
                                      message:
                                          'Tüm ilerleme ve tercihler varsayılan '
                                          'duruma dönecek. Bu işlem geri alınamaz.',
                                      action: widget
                                          .dataManagementService
                                          .resetAllData,
                                      successMessage: 'Tüm veriler sıfırlandı',
                                    ),
                                  ),
                            child: const Text('Tüm verileri sıfırla'),
                          ),
                          if (_isBusy) ...[
                            const SizedBox(height: 16),
                            const Center(child: CircularProgressIndicator()),
                          ],
                        ],
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppDimensions.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
