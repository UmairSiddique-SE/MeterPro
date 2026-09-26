import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

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
        const Duration(seconds: 6),
      );
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final latestVersion = data['latest_version']?.toString().trim() ?? '';
      final apkUrl = data['download_url']?.toString().trim() ?? '';
      final releaseNotes = data['release_notes']?.toString().trim() ?? '';
      final forceUpdate = data['force_update'] == true;

      if (latestVersion.isEmpty || apkUrl.isEmpty) return null;
      if (_versionCompare(package.version, latestVersion) >= 0) return null;

      return AppUpdateInfo(
        version: latestVersion,
        apkUrl: apkUrl,
        releaseNotes: releaseNotes.isNotEmpty
            ? releaseNotes
            : 'Version $latestVersion is ready — tap to install.',
        forceUpdate: forceUpdate,
      );
    } catch (_) {
      return null;
    }
  }

  /// Returns negative if a < b, 0 if equal, positive if a > b
  int _versionCompare(String a, String b) {
    final pa = a.split('.').map(int.tryParse).toList();
    final pb = b.split('.').map(int.tryParse).toList();
    for (int i = 0; i < pa.length || i < pb.length; i++) {
      final va = i < pa.length ? (pa[i] ?? 0) : 0;
      final vb = i < pb.length ? (pb[i] ?? 0) : 0;
      if (va != vb) return va - vb;
    }
    return 0;
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
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon badge
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Update Available!',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'v${update.version}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  update.releaseNotes,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final uri = Uri.tryParse(update.apkUrl);
                      if (uri != null && await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.download_rounded),
                    label: Text(
                      'Download v${update.version}',
                      style:
                          GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                if (!update.forceUpdate) ...[
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(
                      'Remind me later',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.70),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
