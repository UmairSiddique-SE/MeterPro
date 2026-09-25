import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateInfo {
  final String version;
  final String apkUrl;
  final String releaseNotes;
  final bool forceUpdate;

  const AppUpdateInfo({
    required this.version,
    required this.apkUrl,
    required this.releaseNotes,
    this.forceUpdate = false,
  });
}

class AppUpdateService {
  AppUpdateService._();

  static final instance = AppUpdateService._();
  bool _dialogShown = false;

  static final Uri _manifestUri = Uri.parse(
    'https://raw.githubusercontent.com/UmairSiddique-SE/MeterPro/main/version.json',
  );

  Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final package = await PackageInfo.fromPlatform();
      final response = await http.get(_manifestUri).timeout(
        const Duration(seconds: 4),
      );
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final latestVersion = data['latest_version']?.toString().trim() ?? '';
      final apkUrl = data['download_url']?.toString().trim() ?? '';

      if (latestVersion.isEmpty || apkUrl.isEmpty) return null;
      if (latestVersion == package.version) return null;

      return AppUpdateInfo(
        version: latestVersion,
        apkUrl: apkUrl,
        releaseNotes: 'A newer version ($latestVersion) of MeterPro is available with improvements.',
        forceUpdate: false,
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
