import 'package:flutter/material.dart';
import 'package:kelimo/screens/privacy_center_screen.dart';
import 'package:kelimo/services/app_info_provider.dart';
import 'package:kelimo/services/interstitial_ad_service.dart';

class AboutScreen extends StatefulWidget {
  AboutScreen({
    AppInfoProvider? appInfoProvider,
    this.interstitialAdService,
    this.onManageData,
    super.key,
  }) : appInfoProvider = appInfoProvider ?? PackageAppInfoProvider();

  final AppInfoProvider appInfoProvider;
  final InterstitialAdService? interstitialAdService;
  final VoidCallback? onManageData;

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  late final Future<AppVersionInfo> _versionInfo;
  AppVersionInfo? _loadedVersionInfo;

  @override
  void initState() {
    super.initState();
    _versionInfo = widget.appInfoProvider.load().then((value) {
      _loadedVersionInfo = value;
      return value;
    });
  }

  void _openPrivacyCenter() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PrivacyCenterScreen(
          interstitialAdService: widget.interstitialAdService,
          onManageData: widget.onManageData,
        ),
      ),
    );
  }

  void _openLicenses() {
    showLicensePage(
      context: context,
      applicationName: 'Kelimo',
      applicationVersion: _loadedVersionInfo?.displayText,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hakkında')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    label: 'Kelimo uygulaması',
                    child: Column(
                      children: [
                        Text(
                          '📚',
                          style: Theme.of(context).textTheme.displayMedium,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Kelimo',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        FutureBuilder<AppVersionInfo>(
                          future: _versionInfo,
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return Text(
                                snapshot.data!.displayText,
                                key: const ValueKey('about-version'),
                              );
                            }
                            if (snapshot.hasError) {
                              return const Text(
                                'Sürüm bilgisi kullanılamıyor',
                                key: ValueKey('about-version-error'),
                              );
                            }
                            return const Padding(
                              padding: EdgeInsets.all(8),
                              child: SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Card(
                    child: Column(
                      children: [
                        Semantics(
                          button: true,
                          label: 'Gizlilik Merkezini aç',
                          child: ListTile(
                            key: const ValueKey('about-privacy-center'),
                            leading: const Icon(Icons.privacy_tip_outlined),
                            title: const Text('Gizlilik Merkezi'),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: _openPrivacyCenter,
                          ),
                        ),
                        const Divider(height: 1),
                        Semantics(
                          button: true,
                          label: 'Açık kaynak lisanslarını göster',
                          child: ListTile(
                            key: const ValueKey('about-open-source-licenses'),
                            leading: const Icon(Icons.description_outlined),
                            title: const Text('Açık kaynak lisansları'),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: _openLicenses,
                          ),
                        ),
                      ],
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
}
