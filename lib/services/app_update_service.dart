import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateInfo {
  final String version;
  final int buildNumber;
  final String apkUrl;
  final String releaseNotes;
  final bool forceUpdate;

  const AppUpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.apkUrl,
    required this.releaseNotes,
    required this.forceUpdate,
  });
}

class AppUpdateService {
  AppUpdateService._();

  static final instance = AppUpdateService._();
  bool _dialogShown = false;

  Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final package = await PackageInfo.fromPlatform();
      final snapshot = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('android')
          .get();
      final data = snapshot.data();
      if (data == null) return null;

      final latestBuild = (data['buildNumber'] as num?)?.toInt() ?? 0;
      final apkUrl = data['apkUrl'] as String? ?? '';
      if (latestBuild <= int.parse(package.buildNumber) || apkUrl.isEmpty) {
        return null;
      }

      return AppUpdateInfo(
        version: data['version'] as String? ?? 'New version',
        buildNumber: latestBuild,
        apkUrl: apkUrl,
        releaseNotes: data['releaseNotes'] as String? ?? '',
        forceUpdate: data['forceUpdate'] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> checkAndShow(BuildContext context) async {
    if (_dialogShown || !context.mounted) return;
    final update = await checkForUpdate();
    if (update == null || !context.mounted || _dialogShown) return;

    _dialogShown = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: !update.forceUpdate,
      builder: (dialogContext) => PopScope(
        canPop: !update.forceUpdate,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.system_update_rounded),
              SizedBox(width: 10),
              Text('Update available'),
            ],
          ),
          content: Text(update.releaseNotes.isEmpty
              ? 'A newer version of MeterPro is ready to install.'
              : update.releaseNotes),
          actions: [
            if (!update.forceUpdate)
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Later'),
              ),
            FilledButton.icon(
              onPressed: () async {
                final uri = Uri.tryParse(update.apkUrl);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.download_rounded),
              label: Text('Update ${update.version}'),
            ),
          ],
        ),
      ),
    );
  }
}
