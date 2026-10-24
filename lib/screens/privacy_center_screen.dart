import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kelimo/services/interstitial_ad_service.dart';
import 'package:kelimo/theme/app_theme.dart';
import 'package:kelimo/widgets/glass_surface.dart';

class PrivacyCenterScreen extends StatefulWidget {
  const PrivacyCenterScreen({
    this.interstitialAdService,
    this.onManageData,
    this.policyLauncher,
    super.key,
  });

  final InterstitialAdService? interstitialAdService;
  final VoidCallback? onManageData;
  final Future<bool> Function(Uri)? policyLauncher;

  @override
  State<PrivacyCenterScreen> createState() => _PrivacyCenterScreenState();
}

class _PrivacyCenterScreenState extends State<PrivacyCenterScreen> {
  bool _isOpeningPrivacyOptions = false;
  bool _isOpeningPolicy = false;
  static final _policyUri = Uri.parse(
    'https://veles1010.github.io/kelimo/privacy-policy.html',
  );

  Future<void> _openPolicy() async {
    if (_isOpeningPolicy) return;
    setState(() => _isOpeningPolicy = true);
    var opened = false;
    try {
      final launcher = widget.policyLauncher;
      opened = launcher != null
          ? await launcher(_policyUri)
          : await launchUrl(_policyUri, mode: LaunchMode.externalApplication);
    } catch (error) {
      debugPrint('Gizlilik politikası açılamadı: $error');
    }
    if (!mounted) return;
    setState(() => _isOpeningPolicy = false);
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bağlantı açılamadı. Adres: $_policyUri'),
        ),
      );
    }
  }

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
      return GlassBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Gizlilik Merkezi'),
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
          ),
          body: ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              32 + MediaQuery.paddingOf(context).bottom,
            ),
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
                      _PrivacySection(
                        icon: Icons.description_outlined,
                        title: 'Tam gizlilik politikası',
                        description:
                            'Verilerin, reklam hizmetleri ve gizlilik hakların '
                            'hakkındaki tam metni tarayıcıda okuyabilirsin.',
                        action: OutlinedButton.icon(
                          key: const ValueKey('privacy-policy-link'),
                          onPressed: _isOpeningPolicy
                              ? null
                              : () => unawaited(_openPolicy()),
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text('Gizlilik Politikasını Aç'),
                        ),
                      ),
                      const SizedBox(height: 14),
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
                            'Kelimo, banner ve seyrek geçiş reklamları için '
                            'Google Mobile Ads kullanır. Uygun olduğunda izin '
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
      child: GlassSurface(
        enableBlur: false,
        showShadow: false,
        padding: EdgeInsets.zero,
        child: Card(
          color: Colors.transparent,
          surfaceTintColor: Colors.transparent,
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
      ),
    );
  }
}
