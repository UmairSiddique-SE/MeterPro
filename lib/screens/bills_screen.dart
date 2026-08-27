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

  void _showPaymentBottomSheet(
      BuildContext context, String title, double amount,
      {MeterModel? meter, List<MeterModel> meters = const []}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Pay $title bill',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(_pkr.format(amount),
                style: const TextStyle(
                    color: AppColors.primaryLight,
                    fontSize: 28,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 24),
            const Text('SELECT PAYMENT METHOD',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5)),
            const SizedBox(height: 16),
            _paymentMethodTile(ctx, 'JazzCash', Icons.smartphone_rounded,
                Colors.red.shade50, Colors.red, title, amount, meter, meters),
            _paymentMethodTile(
                ctx,
                'EasyPaisa',
                Icons.account_balance_wallet_rounded,
                Colors.green.shade50,
                Colors.green,
                title,
                amount,
                meter,
                meters),
            _paymentMethodTile(
                ctx,
                'Debit / Credit Card',
                Icons.credit_card_rounded,
                Colors.blue.shade50,
                Colors.blue,
                title,
                amount,
                meter,
                meters),
            _paymentMethodTile(
                ctx,
                'Bank Transfer',
                Icons.account_balance_rounded,
                Colors.purple.shade50,
                Colors.purple,
                title,
                amount,
                meter,
                meters),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _paymentMethodTile(
      BuildContext context,
      String label,
      IconData icon,
      Color bg,
      Color iconCol,
      String title,
      double amount,
      MeterModel? meter,
      List<MeterModel> meters) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showPaymentConfirmation(context,
            paymentMethod: label,
            title: title,
            amount: amount,
            meter: meter,
            meters: meters),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, color: iconCol, size: 20),
              ),
              const SizedBox(width: 16),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentConfirmation(BuildContext context,
      {required String paymentMethod,
      required String title,
      required double amount,
      MeterModel? meter,
      List<MeterModel> meters = const []}) {
    final billMeters = meter == null ? meters : [meter];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(4)))),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Confirm bill details',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary)),
                  IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded)),
                ],
              ),
              const Text('Review the bill before continuing.',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border)),
                child: Column(
                  children: [
                    _billDetailRow('Bill name', title),
                    _billDetailRow('Amount due', _pkr.format(amount),
                        valueColor: AppColors.primaryLight),
                    for (final billMeter in billMeters) ...[
                      _billDetailRow('Consumer name', billMeter.name),
                      _billDetailRow('Reference no.', billMeter.referenceNo),
                      if (billMeter.consumerNo.isNotEmpty)
                        _billDetailRow('Consumer no.', billMeter.consumerNo),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (meter != null)
                OutlinedButton.icon(
                  onPressed: () => _launchOnlineBill(ctx, meter.referenceNo),
                  icon: const Icon(Icons.open_in_new_rounded, size: 17),
                  label: const Text('View original live bill'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: AppColors.primaryLight,
                    side: BorderSide(
                        color: AppColors.primaryLight.withValues(alpha: 0.25)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13)),
                  ),
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              '$paymentMethod selected. Connect a payment gateway to complete payment.')),
                    );
                  },
                  icon: const Icon(Icons.lock_outline_rounded, size: 18),
                  label: Text('Continue with $paymentMethod'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _billDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12))),
          const SizedBox(width: 12),
          Flexible(
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: valueColor ?? AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700))),
        ],
      ),
    );
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
                    gradient: AppColors.cardGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
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
                        style:
                            const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () =>
                              _showPaymentBottomSheet(context, 'Total', totalDue, meters: meters),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.15),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            side: const BorderSide(color: Colors.white24),
                          ),
                          child: const Text('Pay All Bills'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: meters.length == 1
                              ? () => _scanBill(context, meters.first)
                              : null,
                          icon: const Icon(Icons.document_scanner_outlined),
                          label: const Text('Scan Latest Bill'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white38),
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
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _launchOnlineBill(context, meters[i].referenceNo),
                                icon: const Icon(Icons.receipt_long_rounded,
                                    size: 16),
                                label: const Text('Online Bill',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  foregroundColor: AppColors.primaryLight,
                                  side: BorderSide(
                                      color: AppColors.primaryLight
                                          .withValues(alpha: 0.2)),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _showPaymentBottomSheet(
                                    context, meters[i].name, meters[i].monthlyBillPkr,
                                    meter: meters[i]),
                                icon: const Icon(Icons.download_rounded,
                                    size: 16),
                                label: const Text('Pay Now',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accentGreen,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
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
