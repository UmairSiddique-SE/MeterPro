import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/meter.dart';
import '../services/meter_repository.dart';
import '../services/ocr_service.dart';
import '../theme/app_theme.dart';
import '../utils/animation_utils.dart';
import 'camera_scanner_screen.dart';

final _pkr =
    NumberFormat.currency(locale: 'en_US', symbol: 'Rs', decimalDigits: 0);

class BillsScreen extends StatelessWidget {
  const BillsScreen({super.key});

  Future<void> _scanBill(BuildContext context, MeterModel meter) async {
    final result = await Navigator.of(context).push<OCRScanResult>(
      MaterialPageRoute(
        builder: (_) => CameraScannerScreen(
          initialMode: ScanTargetMode.bill,
          expectedReferenceNo: meter.referenceNo,
        ),
      ),
    );
    if (!context.mounted || result == null) return;

    final expected = meter.referenceNo.replaceAll(RegExp(r'\D'), '');
    final scanned = result.referenceNo?.replaceAll(RegExp(r'\D'), '') ?? '';
    if (expected.isNotEmpty && scanned.isNotEmpty && expected != scanned) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scanned bill does not belong to this meter.'),
          backgroundColor: AppColors.accentRed,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.meterReading == null
              ? 'Bill scanned, but the present reading was not clear.'
              : 'Bill scanned. Present reading: ${result.meterReading} kWh.',
        ),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Future<void> _launchOnlineBill(
      BuildContext context, String referenceNo) async {
    // Strip spaces and special chars to get pure 14 digits
    final cleanRef = referenceNo.replaceAll(RegExp(r'[^0-9]'), '');
    final url =
        Uri.parse('https://bill.pitc.com.pk/fescobill/general?refno=$cleanRef');

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open bill website.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Bills',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<List<MeterModel>>(
        stream: MeterRepository.instance.watchMeters(),
        builder: (context, snapshot) {
          final meters = snapshot.data ?? const <MeterModel>[];
          final loading = snapshot.connectionState == ConnectionState.waiting;
          final totalDue = totalEstimatedBillPkr(meters);

          if (loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (meters.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_outlined,
                      size: 64, color: AppColors.textMuted),
                  SizedBox(height: 16),
                  Text('No bills available yet',
                      style: TextStyle(color: AppColors.textMuted)),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Top Summary Card
              FadeSlideEntrance(
                delay: const Duration(milliseconds: 100),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: AppColors.blueGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TOTAL AMOUNT DUE',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5)),
                      const SizedBox(height: 8),
                      Text(_pkr.format(totalDue),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(
                        'Due by ${DateFormat('dd MMM yyyy').format(DateTime.now().add(const Duration(days: 15)))} • ${meters.length} meters',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: meters.length == 1
                              ? () => _scanBill(context, meters.first)
                              : null,
                          icon: const Icon(Icons.document_scanner_outlined,
                              size: 18),
                          label: const Text('Scan Latest Bill'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(
                                color: Colors.white60, width: 1.2),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),
              const FadeSlideEntrance(
                delay: Duration(milliseconds: 200),
                child: Text('Individual Bills',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
              ),
              const SizedBox(height: 16),

              // Individual Bills
              for (int i = 0; i < meters.length; i++)
                FadeSlideEntrance(
                  delay: Duration(milliseconds: 300 + (100 * i)),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(meters[i].name,
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary)),
                                  Text(meters[i].referenceNo,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textMuted)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (meters[i].isActive
                                        ? AppColors.accentGreen
                                        : AppColors.accentRed)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                meters[i].isActive ? 'Active' : 'Inactive',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: meters[i].isActive
                                        ? AppColors.accentGreen
                                        : AppColors.accentRed),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('UNITS',
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textMuted)),
                                const SizedBox(height: 4),
                                Text('${meters[i].monthlyUnitsKwh} kWh',
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('AMOUNT DUE',
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textMuted)),
                                const SizedBox(height: 4),
                                Text(_pkr.format(meters[i].monthlyBillPkr),
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.primaryLight)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _launchOnlineBill(
                                context, meters[i].referenceNo),
                            icon: const Icon(Icons.receipt_long_rounded,
                                size: 16),
                            label: const Text('View Online Bill',
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              foregroundColor: AppColors.primary,
                              side: BorderSide(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.3)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
