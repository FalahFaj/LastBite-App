import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppUpdateInfo {
  final bool updateAvailable;
  final bool isForceUpdate;
  final String downloadUrl;
  final String releaseNotes;
  final String latestVersionName;

  AppUpdateInfo({
    required this.updateAvailable,
    required this.isForceUpdate,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.latestVersionName,
  });
}

final updateProvider = FutureProvider<AppUpdateInfo>((ref) async {
  // 1. Dapatkan versi aplikasi saat ini dari HP
  final packageInfo = await PackageInfo.fromPlatform();
  // Di Android, buildNumber biasanya diubah menjadi int dan mewakili versionCode
  final currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 1;

  // 2. Ambil versi terbaru dari Supabase
  final response = await Supabase.instance.client
      .from('app_versions')
      .select()
      .order('version_code', ascending: false)
      .limit(1)
      .maybeSingle();

  // Jika tidak ada data di tabel
  if (response == null) {
    return AppUpdateInfo(
      updateAvailable: false,
      isForceUpdate: false,
      downloadUrl: '',
      releaseNotes: '',
      latestVersionName: packageInfo.version,
    );
  }

  final latestVersionCode = response['version_code'] as int;
  final latestVersionName = response['version_name'] as String;
  final downloadUrl = response['download_url'] as String? ?? '';
  final isForceUpdate = response['is_force_update'] as bool? ?? false;
  final releaseNotes = response['release_notes'] as String? ?? '';

  // 3. Bandingkan versi
  final bool needsUpdate = latestVersionCode > currentVersionCode;

  return AppUpdateInfo(
    updateAvailable: needsUpdate,
    isForceUpdate: isForceUpdate,
    downloadUrl: downloadUrl,
    releaseNotes: releaseNotes,
    latestVersionName: latestVersionName,
  );
});
