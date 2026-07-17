import 'package:package_info_plus/package_info_plus.dart';

class AppVersionInfo {
  const AppVersionInfo({required this.version, required this.buildNumber});

  final String version;
  final String buildNumber;

  String get displayText => 'Sürüm $version • Yapı $buildNumber';
}

abstract interface class AppInfoProvider {
  Future<AppVersionInfo> load();
}

class PackageAppInfoProvider implements AppInfoProvider {
  @override
  Future<AppVersionInfo> load() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return AppVersionInfo(
      version: packageInfo.version,
      buildNumber: packageInfo.buildNumber,
    );
  }
}
