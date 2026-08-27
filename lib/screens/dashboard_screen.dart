import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/meter.dart';
import '../services/meter_repository.dart';
import '../services/ocr_service.dart';
import '../theme/app_theme.dart';
import '../utils/animation_utils.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/meter_card.dart';
import 'add_meter_screen.dart';
import 'bills_screen.dart';
import 'camera_scanner_screen.dart';
import 'meter_detail_screen.dart';
import 'profile_screen.dart';
import 'services_screen.dart';
import 'usage_screen.dart';

final _pkr =
    NumberFormat.currency(locale: 'en_US', symbol: 'Rs', decimalDigits: 0);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _navIndex = 0;
  static final Uri _versionManifestUri = Uri.parse(
    'https://raw.githubusercontent.com/UmairSiddique-SE/MeterPro/main/version.json',
  );

  @override
  void initState() {
    super.initState();
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    try {
      final response = await http.get(_versionManifestUri);
      if (response.statusCode != 200) return;

      final manifest = jsonDecode(response.body) as Map<String, dynamic>;
      final latestVersion = manifest['latest_version']?.toString().trim();
      final downloadUrl = manifest['download_url']?.toString().trim();
      if (latestVersion == null ||
          latestVersion.isEmpty ||
          downloadUrl == null ||
          downloadUrl.isEmpty) {
        return;
      }

      final packageInfo = await PackageInfo.fromPlatform();
      if (!mounted || packageInfo.version == latestVersion) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Update Available'),
          content: Text(
            'A new version ($latestVersion) of MeterPro is available. '
            'Please update to continue using the latest features.',
          ),
          actions: [
            ElevatedButton.icon(
              onPressed: () async {
                final uri = Uri.tryParse(downloadUrl);
                if (uri == null ||
                    !await launchUrl(uri,
                        mode: LaunchMode.externalApplication)) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                          content: Text('Could not open update link.')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.download_rounded),
              label: const Text('Update Now'),
            ),
          ],
        ),
      );
    } catch (_) {
      // Update checks must not prevent the app from opening offline.
    }
  }

  void _openMeter(MeterModel meter) async {
    final result = await Navigator.of(context).push<String>(
      SmoothPageRoute(child: MeterDetailScreen(meter: meter)),
    );
    if (result == 'go_to_usage') {
      setState(() => _navIndex = 1);
    }
  }

  void _openAddMeter() {
    Navigator.of(context).push(
      SmoothPageRoute(child: const AddMeterScreen()),
    );
  }

  Future<void> _quickScanMeter(
      BuildContext context, List<MeterModel> meters) async {
    if (meters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Add a meter first, then use quick scan.')),
      );
      return;
    }
    final result = await Navigator.of(context).push<OCRScanResult>(
      MaterialPageRoute(
        builder: (_) => CameraScannerScreen(
          registeredMeterNumbers: meters.map((meter) => meter.meterNo).toList(),
          scanSerialOnly: true,
        ),
      ),
    );
    if (!context.mounted || result?.meterNo == null) return;
    final scanned =
        result!.meterNo!.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();
    final matches = meters.where((meter) =>
        meter.meterNo.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase() ==
        scanned);
    if (matches.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => MeterDetailScreen(meter: matches.first)),
      );
    }
  }

  Future<bool> _showExitDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit App?'),
        content: const Text('Are you sure you want to exit MeterPro?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _DashboardHome(
        onOpenMeter: _openMeter,
        onAddMeter: _openAddMeter,
        onViewBills: () => setState(() => _navIndex = 2),
        onScanMeter: (meters) => _quickScanMeter(context, meters),
        onOpenProfile: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        ),
      ),
      const UsageScreen(),
      const BillsScreen(),
      const ServicesScreen(),
    ];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_navIndex != 0) {
          setState(() => _navIndex = 0);
          return;
        }
        final shouldExit = await _showExitDialog();
        if (shouldExit) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: KeyedSubtree(
            key: ValueKey<int>(_navIndex),
            child: pages[_navIndex],
          ),
        ),
        floatingActionButton: _navIndex == 0
            ? StreamBuilder<List<MeterModel>>(
                stream: MeterRepository.instance.watchMeters(),
                builder: (context, snapshot) {
                  final meters = snapshot.data ?? [];
                  return FloatingActionButton(
                    onPressed: () => _quickScanMeter(context, meters),
                    backgroundColor: AppColors.primary,
                    child: const Icon(Icons.qr_code_scanner_rounded,
                        color: Colors.white),
                  );
                },
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: MWBottomNavBar(
          currentIndex: _navIndex,
          onTap: (i) => setState(() => _navIndex = i),
        ),
      ),
    );
  }
}

class _DashboardHome extends StatelessWidget {
  final ValueChanged<MeterModel> onOpenMeter;
  final VoidCallback onAddMeter;
  final VoidCallback onViewBills;
  final Function(List<MeterModel>) onScanMeter;
  final VoidCallback onOpenProfile;

  const _DashboardHome({
    required this.onOpenMeter,
    required this.onAddMeter,
    required this.onViewBills,
    required this.onScanMeter,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : 'User';
    final initials = displayName.trim().isEmpty
        ? '?'
        : displayName
            .trim()
            .split(RegExp(r'\s+'))
            .map((w) => w[0])
            .take(2)
            .join()
            .toUpperCase();
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning,'
        : (hour < 17 ? 'Good afternoon,' : 'Good evening,');

    return StreamBuilder<List<MeterModel>>(
      stream: MeterRepository.instance.watchMeters(),
      builder: (context, snapshot) {
        final meters = snapshot.data ?? const <MeterModel>[];
        final loading = snapshot.connectionState == ConnectionState.waiting;

        return SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  decoration: const BoxDecoration(
                    gradient: AppColors.headerGradient,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(greeting,
                                  style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700)),
                              Text(displayName,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              if (meters.isNotEmpty) const SizedBox(height: 2),
                            ],
                          ),
                          Row(
                            children: [
                              InkWell(
                                onTap: onOpenProfile,
                                borderRadius: BorderRadius.circular(22),
                                child: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: const Color(0xFF3A5AC0),
                                  child: Text(initials,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.94, end: 1),
                        duration: const Duration(milliseconds: 650),
                        curve: Curves.easeOutCubic,
                        builder: (context, scale, child) => Transform.scale(
                          scale: scale,
                          alignment: Alignment.topCenter,
                          child: child,
                        ),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.15),
                                Colors.white.withValues(alpha: 0.04),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 30,
                                offset: const Offset(0, 15),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                            color: AppColors.accentGreen,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                  color: AppColors.accentGreen,
                                                  blurRadius: 4)
                                            ]),
                                      ),
                                      const SizedBox(width: 8),
                                      Text('LIVE STATUS',
                                          style: TextStyle(
                                              color: Colors.white
                                                  .withValues(alpha: 0.7),
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 1.5)),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                        '${meters.length} ${meters.length == 1 ? 'METER' : 'METERS'}',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text('TOTAL CONSUMPTION',
                                            style: TextStyle(
                                                color: Color(0x80FFFFFF),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.5)),
                                      ),
                                      const SizedBox(height: 6),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.baseline,
                                          textBaseline: TextBaseline.alphabetic,
                                          children: [
                                            Text(
                                                totalConsumptionKwh(meters)
                                                    .toStringAsFixed(0),
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 44,
                                                    letterSpacing: -1,
                                                    fontWeight:
                                                        FontWeight.w900)),
                                            const SizedBox(width: 4),
                                            Text('kWh',
                                                style: TextStyle(
                                                    color: Colors.white
                                                        .withValues(alpha: 0.4),
                                                    fontSize: 14,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 40,
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      const FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerRight,
                                        child: Text('ESTIMATED BILL',
                                            style: TextStyle(
                                                color: Color(0x80FFFFFF),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.5)),
                                      ),
                                      const SizedBox(height: 6),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          _pkr.format(
                                              totalEstimatedBillPkr(meters)),
                                          style: const TextStyle(
                                              color: AppColors.accentOrange,
                                              fontSize: 24,
                                              fontWeight: FontWeight.w900),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Your energy',
                                style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: 2),
                            Text('My Meters (${meters.length})',
                                style: Theme.of(context).textTheme.titleLarge),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: onAddMeter,
                          icon: const Icon(Icons.add_circle_outline_rounded,
                              size: 16),
                          label: const Text('Add Meter',
                              style: TextStyle(
                                  color: AppColors.primaryLight,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (meters.isEmpty)
                      _EmptyMetersCard(onAddMeter: onAddMeter)
                    else
                      GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.78,
                        ),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: meters.length,
                        itemBuilder: (context, index) {
                          final m = meters[index];
                          return FadeSlideEntrance(
                            delay: Duration(milliseconds: 100 * index),
                            child: MeterCard(
                                meter: m, onTap: () => onOpenMeter(m)),
                          );
                        },
                      ),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyMetersCard extends StatelessWidget {
  final VoidCallback onAddMeter;
  const _EmptyMetersCard({required this.onAddMeter});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.bolt_rounded,
                color: AppColors.primary, size: 28),
          ),
          const SizedBox(height: 14),
          Text('No meters yet', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Add your first electricity meter to start tracking usage and bills.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onAddMeter,
            icon: const Icon(Icons.add),
            label: const Text('Add Meter'),
          ),
        ],
      ),
    );
  }
}
