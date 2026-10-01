import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_theme.dart';

/// Centralized service to handle Android/iOS permissions for the MeterUnit app.
class PermissionService {
  PermissionService._();
  static final PermissionService instance = PermissionService._();

  /// Requests all permissions needed for a "full access" experience early in the app lifecycle.
  Future<void> requestEssentialPermissions(BuildContext context) async {
    // Request Camera as it's the most critical for scanning
    final cameraStatus = await Permission.camera.request();

    if (cameraStatus.isPermanentlyDenied) {
      if (context.mounted) {
        _showSettingsDialog(context, 'Camera');
      }
    }

    // Optional: Request storage for high-quality bill image logs if needed in future
    // In Android 13+, this is READ_MEDIA_IMAGES
    await Permission.photos.request();
  }

  /// Checks if camera permission is granted without requesting.
  Future<bool> hasCameraPermission() async {
    return await Permission.camera.isGranted;
  }

  /// Specialized request for Camera specifically.
  Future<bool> requestCamera(BuildContext context) async {
    final status = await Permission.camera.request();
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied && context.mounted) {
      _showSettingsDialog(context, 'Camera');
    }
    return false;
  }

  void _showSettingsDialog(BuildContext context, String permissionName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$permissionName Permission Required'),
        content: Text(
          'MeterPro needs $permissionName access to scan bills and meters. '
          'Please enable it in the app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
