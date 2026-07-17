import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kelimo/services/interstitial_ad_service.dart';
import 'package:kelimo/theme/app_theme.dart';

class PrivacyCenterScreen extends StatefulWidget {
  const PrivacyCenterScreen({
    this.interstitialAdService,
    this.onManageData,
    super.key,
  });

  final InterstitialAdService? interstitialAdService;
  final VoidCallback? onManageData;

  @override
  State<PrivacyCenterScreen> createState() => _PrivacyCenterScreenState();
}

class _PrivacyCenterScreenState extends State<PrivacyCenterScreen> {
  bool _isOpeningPrivacyOptions = false;

  Future<void> _showPrivacyOptions() async {
    final service = widget.interstitialAdService;
    if (service == null || _isOpeningPrivacyOptions) return;
    setState(() => _isOpeningPrivacyOptions = true);
    final shown = await service.showPrivacyOptions();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          shown
              ? 'Reklam gizliliği seçenekleri güncellendi'
              : 'Reklam gizliliği seçenekleri açılamadı',
        ),
      ),
    );
    setState(() => _isOpeningPrivacyOptions = false);
  }

  @override
  Widget build(BuildContext context) {
    Widget buildContent() {
      final adService = widget.interstitialAdService;
      return Scaffold(
        appBar: AppBar(title: const Text('Gizlilik Merkezi')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'Gizlilik Özeti',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Kelimo’nun verilerini nasıl sakladığını ve '
                      'seçeneklerini nasıl yönetebileceğini burada görebilirsin.',
                    ),
                    const SizedBox(height: 18),
                    const _PrivacySection(
                      icon: Icons.storage_rounded,
                      title: 'Öğrenme verilerin',
                      description:
                          'Kelime ilerlemen, favorilerin, quiz geçmişin, XP, '
                          'seri bilgilerin ve ayarların cihazındaki yerel '
                          'SQLite veritabanında tutulur.',
                    ),
                    const SizedBox(height: 14),
                    const _PrivacySection(
                      icon: Icons.cloud_off_rounded,
                      title: 'Hesap ve bulut',
                      description:
                          'Kelimo’da hesap oluşturma ve bulut senkronizasyonu '
                          'yoktur. Öğrenme verilerin başka bir cihaza otomatik '
                          'olarak aktarılmaz.',
                    ),
                    const SizedBox(height: 14),
                    const _PrivacySection(
                      icon: Icons.notifications_outlined,
                      title: 'Hatırlatıcılar',
                      description:
                          'Günlük çalışma hatırlatıcısı cihazının yerel bildirim '
                          'sistemiyle çalışır ve bildirim iznine bağlıdır.',
                    ),
                    const SizedBox(height: 14),
                    _PrivacySection(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Reklamlar ve seçimlerin',
                      description:
                          'Kelimo, seyrek geçiş reklamları için Google Mobile '
                          'Ads kullanır. Uygun olduğunda reklam gizliliği ve izin '
                          'seçeneklerini gözden geçirebilirsin.',
                      action: adService?.privacyOptionsRequired == true
                          ? Semantics(
                              button: true,
                              label: 'Reklam gizliliği seçeneklerini aç',
                              child: OutlinedButton.icon(
                                key: const ValueKey(
                                  'privacy-center-ad-options',
                                ),
                                onPressed: _isOpeningPrivacyOptions
                                    ? null
                                    : () => unawaited(_showPrivacyOptions()),
                                icon: const Icon(Icons.tune_rounded),
                                label: const Text(
                                  'Reklam gizliliği seçenekleri',
                                ),
                              ),
                            )
                          : const Text(
                              'Şu anda ek reklam gizliliği seçeneği yok.',
                            ),
                    ),
                    const SizedBox(height: 14),
                    _PrivacySection(
                      icon: Icons.delete_outline_rounded,
                      title: 'Verilerini yönet',
                      description:
                          'Öğrenme verilerini veya tüm verileri buradan '
                          'silebilirsin.',
                      action: Semantics(
                        button: true,
                        label: 'Ayarlar veri yönetimi bölümüne git',
                        child: ListTile(
                          key: const ValueKey('privacy-manage-data'),
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Veri Yönetimine Git'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: widget.onManageData,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final adService = widget.interstitialAdService;
    if (adService == null) return buildContent();
    return AnimatedBuilder(
      animation: adService,
      builder: (_, _) => buildContent(),
    );
  }
}

class _PrivacySection extends StatelessWidget {
  const _PrivacySection({
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: title,
      child: Card(
        child: Padding(
          padding: AppDimensions.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(description),
              if (action != null) ...[const SizedBox(height: 12), action!],
            ],
          ),
        ),
      ),
    );
  }
}
