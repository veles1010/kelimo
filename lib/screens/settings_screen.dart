import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kelimo/models/app_settings.dart';
import 'package:kelimo/services/data_management_service.dart';
import 'package:kelimo/services/daily_reminder_service.dart';
import 'package:kelimo/services/english_tts_service.dart';
import 'package:kelimo/services/notification_service.dart';
import 'package:kelimo/services/settings_service.dart';
import 'package:kelimo/theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.settingsService,
    required this.dataManagementService,
    this.previewTtsService,
    this.dailyReminderService,
    super.key,
  });

  final SettingsService settingsService;
  final DataManagementService dataManagementService;
  final EnglishTtsService? previewTtsService;
  final DailyReminderService? dailyReminderService;

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

  Future<void> _setReminderEnabled(bool enabled) async {
    final service = widget.dailyReminderService;
    if (service == null || _isBusy) return;
    setState(() => _isBusy = true);
    final result = await service.setEnabled(enabled);
    if (!mounted) return;
    final message = switch (result) {
      ReminderUpdateResult.success =>
        enabled ? 'Günlük hatırlatıcı açıldı' : 'Günlük hatırlatıcı kapatıldı',
      ReminderUpdateResult.permissionDenied =>
        'Bildirim izni verilmedi. Hatırlatıcı açılamadı.',
      ReminderUpdateResult.permanentlyDenied =>
        'Bildirim izni kapalı. Cihaz ayarlarından izin vermelisin.',
      ReminderUpdateResult.failed => 'Hatırlatıcı güncellenemedi',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    setState(() => _isBusy = false);
  }

  Future<void> _pickReminderTime() async {
    final service = widget.dailyReminderService;
    if (service == null || _isBusy) return;
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: service.hour, minute: service.minute),
      helpText: 'Hatırlatma saatini seç',
      cancelText: 'İptal',
      confirmText: 'Kaydet',
    );
    if (selected == null || !mounted) return;
    setState(() => _isBusy = true);
    final saved = await service.setTime(
      hour: selected.hour,
      minute: selected.minute,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Hatırlatma saati güncellendi'
              : 'Hatırlatma saati planlanamadı',
        ),
      ),
    );
    setState(() => _isBusy = false);
  }

  Future<void> _requestNotificationPermission() async {
    final service = widget.dailyReminderService;
    if (service == null || _isBusy) return;
    setState(() => _isBusy = true);
    final status = await service.requestPermission();
    if (!mounted) return;
    final message = switch (status) {
      NotificationPermissionStatus.granted => 'Bildirim izni verildi',
      NotificationPermissionStatus.permanentlyDenied =>
        'İzin kapalı. Cihaz ayarlarından bildirimlere izin vermelisin.',
      _ => 'Bildirim izni verilmedi',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    setState(() => _isBusy = false);
  }

  Future<void> _testNotification() async {
    final service = widget.dailyReminderService;
    if (service == null || _isBusy) return;
    setState(() => _isBusy = true);
    final result = await service.scheduleTestNotification();
    if (!mounted) return;
    final message = switch (result) {
      ReminderUpdateResult.success =>
        'Test bildirimi 10 saniye sonrası için planlandı',
      ReminderUpdateResult.permissionDenied =>
        'Bildirim izni verilmedi. Test bildirimi planlanamadı.',
      ReminderUpdateResult.permanentlyDenied =>
        'Bildirim izni kapalı. Cihaz ayarlarından izin vermelisin.',
      ReminderUpdateResult.failed => 'Test bildirimi planlanamadı',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    setState(() => _isBusy = false);
  }

  Future<void> _resetPreferences() async {
    final reminderService = widget.dailyReminderService;
    if (reminderService != null) {
      await reminderService.resetPreferences();
    } else {
      await widget.settingsService.resetToDefaults();
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
        animation: widget.dailyReminderService == null
            ? widget.settingsService
            : Listenable.merge([
                widget.settingsService,
                widget.dailyReminderService!,
              ]),
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
                    if (widget.dailyReminderService case final service?) ...[
                      _Section(
                        title: 'Hatırlatıcılar',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SwitchListTile.adaptive(
                              key: const ValueKey('daily-reminder-switch'),
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Günlük çalışma hatırlatıcısı'),
                              subtitle: const Text(
                                'Her gün seçtiğin saatte çalışmanı hatırlatır.',
                              ),
                              value: service.isEnabled,
                              onChanged: _isBusy || service.isLoading
                                  ? null
                                  : (value) =>
                                        unawaited(_setReminderEnabled(value)),
                            ),
                            const SizedBox(height: 8),
                            ListTile(
                              key: const ValueKey('reminder-time-tile'),
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.schedule_rounded),
                              title: const Text('Hatırlatma saati'),
                              subtitle: Text(
                                formatReminderTime24Hour(
                                  service.hour,
                                  service.minute,
                                ),
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              enabled: !_isBusy,
                              onTap: _isBusy
                                  ? null
                                  : () => unawaited(_pickReminderTime()),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Bildirim izni: ${_permissionLabel(service.permissionStatus)}',
                            ),
                            if (service.permissionStatus !=
                                NotificationPermissionStatus.granted) ...[
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: _isBusy
                                    ? null
                                    : () => unawaited(
                                        _requestNotificationPermission(),
                                      ),
                                icon: const Icon(
                                  Icons.notifications_active_outlined,
                                ),
                                label: const Text('Bildirim izni ver'),
                              ),
                            ],
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              key: const ValueKey('test-reminder-notification'),
                              onPressed: _isBusy
                                  ? null
                                  : () => unawaited(_testNotification()),
                              icon: const Icon(Icons.notification_add_outlined),
                              label: const Text('Bildirimi test et'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
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
                                          'Günlük hedef, telaffuz hızı ve '
                                          'hatırlatıcı ayarları varsayılan '
                                          'değerlere dönecek. Öğrenme '
                                          'verilerin korunacak.',
                                      action: _resetPreferences,
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

String formatReminderTime24Hour(int hour, int minute) {
  return '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';
}

String _permissionLabel(NotificationPermissionStatus status) {
  return switch (status) {
    NotificationPermissionStatus.granted => 'İzin verildi',
    NotificationPermissionStatus.permanentlyDenied =>
      'Cihaz ayarlarında kapalı',
    NotificationPermissionStatus.denied => 'İzin verilmedi',
    NotificationPermissionStatus.unknown => 'Kontrol ediliyor',
  };
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
