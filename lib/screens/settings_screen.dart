import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:kelimo/models/app_settings.dart';
import 'package:kelimo/screens/about_screen.dart';
import 'package:kelimo/screens/privacy_center_screen.dart';
import 'package:kelimo/services/app_info_provider.dart';
import 'package:kelimo/services/data_management_service.dart';
import 'package:kelimo/services/daily_reminder_service.dart';
import 'package:kelimo/services/english_tts_service.dart';
import 'package:kelimo/services/notification_service.dart';
import 'package:kelimo/services/settings_service.dart';
import 'package:kelimo/services/interstitial_ad_service.dart';
import 'package:kelimo/theme/app_theme.dart';
import 'package:kelimo/widgets/glass_surface.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.settingsService,
    required this.dataManagementService,
    this.previewTtsService,
    this.dailyReminderService,
    this.interstitialAdService,
    this.appInfoProvider,
    this.onShowOnboarding,
    super.key,
  });

  final SettingsService settingsService;
  final DataManagementService dataManagementService;
  final EnglishTtsService? previewTtsService;
  final DailyReminderService? dailyReminderService;
  final InterstitialAdService? interstitialAdService;
  final AppInfoProvider? appInfoProvider;
  final VoidCallback? onShowOnboarding;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final EnglishTtsService _ttsService;
  late final bool _ownsTtsService;
  bool _isBusy = false;
  final GlobalKey _dataManagementKey = GlobalKey();

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

  Future<void> _setThemeMode(ThemePreference? value) async {
    if (value == null || _isBusy) return;
    await _run(
      () => widget.settingsService.setThemeMode(value),
      successMessage: 'Tema tercihi kaydedildi',
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

  Future<void> _showPrivacyOptions() async {
    final service = widget.interstitialAdService;
    if (service == null || _isBusy) return;
    setState(() => _isBusy = true);
    final shown = await service.showPrivacyOptions();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          shown
              ? 'Gizlilik seçenekleri güncellendi'
              : 'Gizlilik seçenekleri açılamadı',
        ),
      ),
    );
    setState(() => _isBusy = false);
  }

  Future<void> _showTestAd() async {
    final service = widget.interstitialAdService;
    if (service == null || _isBusy) return;
    setState(() => _isBusy = true);
    final shown = await service.showTestAd();
    if (!mounted) return;
    if (!shown) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test reklamı henüz hazır değil')),
      );
    }
    setState(() => _isBusy = false);
  }

  void _openAbout() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AboutScreen(
          appInfoProvider: widget.appInfoProvider,
          interstitialAdService: widget.interstitialAdService,
          onManageData: _showDataManagement,
        ),
      ),
    );
  }

  void _openPrivacyCenter() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PrivacyCenterScreen(
          interstitialAdService: widget.interstitialAdService,
          onManageData: _showDataManagement,
        ),
      ),
    );
  }

  void _showDataManagement() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetContext = _dataManagementKey.currentContext;
      if (!mounted || targetContext == null) return;
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
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
    final isCompact = MediaQuery.sizeOf(context).width < 360;
    final navigationClearance = 70 + MediaQuery.paddingOf(context).bottom + 24;
    return GlassBackground(
      child: SafeArea(
        bottom: false,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            widget.settingsService,
            if (widget.dailyReminderService != null)
              widget.dailyReminderService!,
            if (widget.interstitialAdService != null)
              widget.interstitialAdService!,
          ]),
          builder: (context, child) => ListView(
            padding: EdgeInsets.fromLTRB(
              isCompact ? 16 : 24,
              28,
              isCompact ? 16 : 24,
              navigationClearance,
            ),
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
                        title: 'Uygulama',
                        child: Column(
                          children: [
                            Semantics(
                              button: true,
                              label: 'Kelimo hakkında ekranını aç',
                              child: ListTile(
                                key: const ValueKey('settings-about'),
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.info_outline_rounded),
                                title: const Text('Hakkında'),
                                trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                ),
                                onTap: _openAbout,
                              ),
                            ),
                            if (widget.onShowOnboarding != null) ...[
                              const Divider(height: 1),
                              Semantics(
                                button: true,
                                label: 'Başlangıç rehberini yeniden göster',
                                child: ListTile(
                                  key: const ValueKey('show-onboarding-guide'),
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(
                                    Icons.auto_stories_outlined,
                                  ),
                                  title: const Text(
                                    'Başlangıç rehberini göster',
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right_rounded,
                                  ),
                                  onTap: widget.onShowOnboarding,
                                ),
                              ),
                            ],
                            const Divider(height: 1),
                            Semantics(
                              button: true,
                              label: 'Gizlilik Merkezini aç',
                              child: ListTile(
                                key: const ValueKey('settings-privacy-center'),
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.shield_outlined),
                                title: const Text('Gizlilik Merkezi'),
                                trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                ),
                                onTap: _openPrivacyCenter,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _Section(
                        title: 'Görünüm',
                        child: Semantics(
                          label: 'Uygulama teması seçimi',
                          child: DropdownButtonFormField<ThemePreference>(
                            isExpanded: true,
                            key: ValueKey(
                              'theme-mode-${widget.settingsService.themeMode.storageValue}',
                            ),
                            initialValue: widget.settingsService.themeMode,
                            decoration: const InputDecoration(
                              labelText: 'Tema',
                              helperText: 'Uygulamanın görünümünü seç',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final theme in ThemePreference.values)
                                DropdownMenuItem(
                                  value: theme,
                                  child: Text(theme.label),
                                ),
                            ],
                            onChanged: _isBusy
                                ? null
                                : (value) => unawaited(_setThemeMode(value)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _Section(
                        title: 'Öğrenme',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DropdownButtonFormField<int>(
                              isExpanded: true,
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
                                title: const Text(
                                  'Günlük çalışma hatırlatıcısı',
                                ),
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
                                trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                ),
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
                              if (kDebugMode) ...[
                                const SizedBox(height: 10),
                                GlassSurface(
                                  enableBlur: false,
                                  showShadow: false,
                                  borderRadius: BorderRadius.circular(16),
                                  padding: EdgeInsets.zero,
                                  child: OutlinedButton.icon(
                                    key: const ValueKey(
                                      'test-reminder-notification',
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide.none,
                                    ),
                                    onPressed: _isBusy
                                        ? null
                                        : () => unawaited(_testNotification()),
                                    icon: const Icon(
                                      Icons.notification_add_outlined,
                                    ),
                                    label: const Text('Bildirimi test et'),
                                  ),
                                ),
                              ],
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
                              isExpanded: true,
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
                            GlassSurface(
                              enableBlur: false,
                              showShadow: false,
                              borderRadius: BorderRadius.circular(16),
                              padding: EdgeInsets.zero,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide.none,
                                ),
                                onPressed: _isBusy
                                    ? null
                                    : () => unawaited(_testVoice()),
                                icon: const Icon(Icons.volume_up_rounded),
                                label: const Text('Sesi dene'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (widget.interstitialAdService
                          case final adService?) ...[
                        _Section(
                          title: 'Gizlilik ve Reklamlar',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Geçiş reklamları yalnızca quiz sonrasındaki '
                                'doğal çıkışlarda ve seyrek olarak gösterilebilir.',
                              ),
                              if (adService.privacyOptionsRequired) ...[
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  key: const ValueKey('privacy-options-button'),
                                  onPressed: _isBusy
                                      ? null
                                      : () => unawaited(_showPrivacyOptions()),
                                  icon: const Icon(Icons.privacy_tip_outlined),
                                  label: const Text('Gizlilik seçenekleri'),
                                ),
                              ],
                              if (kDebugMode) ...[
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  key: const ValueKey(
                                    'test-interstitial-button',
                                  ),
                                  onPressed: _isBusy
                                      ? null
                                      : () => unawaited(_showTestAd()),
                                  icon: const Icon(Icons.ad_units_outlined),
                                  label: const Text('Test reklamını göster'),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _Section(
                        key: _dataManagementKey,
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
                              child: const Text(
                                'Tercihleri varsayılana döndür',
                              ),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.secondary,
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
                                        successMessage:
                                            'Tüm veriler sıfırlandı',
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
  const _Section({required this.title, required this.child, super.key});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.sizeOf(context).width < 360
        ? const EdgeInsets.all(18)
        : AppDimensions.cardPadding;
    return GlassSurface(
      enableBlur: false,
      padding: EdgeInsets.zero,
      child: Card(
        color: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        child: Padding(
          padding: padding,
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
      ),
    );
  }
}
