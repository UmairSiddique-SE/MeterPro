import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/meter.dart';
import '../theme/app_theme.dart';
import '../utils/animation_utils.dart';
import 'meters_screen.dart';

final _pkr = NumberFormat.currency(locale: 'en_US', symbol: 'Rs ', decimalDigits: 0);
final _pkrDec = NumberFormat.currency(locale: 'en_US', symbol: 'Rs ', decimalDigits: 2);

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  void _showUnitCalculator(BuildContext context) {
    final startCtrl = TextEditingController();
    final presentCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Container(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Unit Calculator', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('Calculate consumed units from your meter readings.', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              const SizedBox(height: 24),
              _inputField(startCtrl, 'Start Reading (kWh)', Icons.speed_rounded),
              const SizedBox(height: 16),
              _inputField(presentCtrl, 'Present Reading (kWh)', Icons.bolt_rounded),
              const SizedBox(height: 24),
              Builder(builder: (context) {
                final start = int.tryParse(startCtrl.text) ?? 0;
                final present = int.tryParse(presentCtrl.text) ?? 0;
                final diff = (present - start).clamp(0, 999999);
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    children: [
                      const Text('TOTAL CONSUMED UNITS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 1)),
                      const SizedBox(height: 4),
                      Text('$diff kWh', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.primary)),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBillCalculator(BuildContext context) {
    final unitsCtrl = TextEditingController(text: '100');
    int load = 1;
    bool isProtected = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final units = int.tryParse(unitsCtrl.text) ?? 0;
          final breakdown = calculateBillBreakdown(units, sanctionedLoad: load, isProtected: isProtected);

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.85,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bill Calculator', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _inputField(unitsCtrl, 'Units (kWh)', Icons.electric_bolt_rounded, onChanged: (v) => setState(() {}))),
                    const SizedBox(width: 12),
                    _loadSelector(load, (v) => setState(() => load = v)),
                  ],
                ),
                const SizedBox(height: 16),
                _protectedToggle(isProtected, (v) => setState(() => isProtected = v)),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    children: [
                      _calcRow('Base Energy', breakdown.baseEnergyCost),
                      _calcRow('Fixed Charges', breakdown.fixedCharge),
                      if (breakdown.subsidy != 0) _calcRow('Subsidy', breakdown.subsidy, color: Colors.green),
                      _calcRow('ED (Duty)', breakdown.electricityDuty),
                      _calcRow('Sales Tax', breakdown.salesTax),
                      _calcRow('TV Fee', breakdown.tvFee),
                      const Divider(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('ESTIMATED TOTAL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                          Text(_pkr.format(breakdown.totalBillPkr), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: AppColors.accentOrange)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text('* Rates are based on latest FESCO tariff slabs.', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset('assets/images/logo.png', width: 28, height: 28),
            ),
            const SizedBox(width: 12),
            const Text('Utility Services', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          ],
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FadeSlideEntrance(
            delay: const Duration(milliseconds: 50),
            child: _serviceCard(
              context,
              Icons.public_rounded,
              'Check Online Bill',
              'Open FESCO official portal to view or download your duplicate bill.',
              Colors.blue,
              () => _launchUrl('https://bill.pitc.com.pk/fescobill'),
            ),
          ),
          FadeSlideEntrance(
            delay: const Duration(milliseconds: 150),
            child: _serviceCard(
              context,
              Icons.calculate_rounded,
              'Unit Calculator',
              'Manually calculate units by entering start and end meter readings.',
              Colors.purple,
              () => _showUnitCalculator(context),
            ),
          ),
          FadeSlideEntrance(
            delay: const Duration(milliseconds: 250),
            child: _serviceCard(
              context,
              Icons.receipt_long_rounded,
              'Bill Calculator',
              'Estimate your monthly bill breakdown with taxes and tariff slabs.',
              Colors.orange,
              () => _showBillCalculator(context),
            ),
          ),
          FadeSlideEntrance(
            delay: const Duration(milliseconds: 350),
            child: _serviceCard(
              context,
              Icons.electric_meter_rounded,
              'Manage Meters',
              'View, edit, or remove your registered electricity meters.',
              AppColors.primary,
              () => Navigator.push(
                context,
                SmoothPageRoute(child: const MetersScreen()),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const FadeSlideEntrance(
            delay: Duration(milliseconds: 450),
            child: Text('OTHER UTILITIES',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMuted,
                    letterSpacing: 1.5)),
          ),
          const SizedBox(height: 12),
          FadeSlideEntrance(
            delay: const Duration(milliseconds: 550),
            child: _simpleTile(Icons.support_agent_rounded, 'FESCO Helpline', '118', () => _launchUrl('tel:118')),
          ),
          FadeSlideEntrance(
            delay: const Duration(milliseconds: 650),
            child: _simpleTile(Icons.calendar_month_rounded, 'Load Shedding Schedule', 'Check your area timings', () => _launchUrl('https://fesco.com.pk/outs/loadshedding')),
          ),
        ],
      ),
    );
  }

  Widget _serviceCard(BuildContext context, IconData icon, String title, String desc, Color color, VoidCallback onTap) {
    return ScaleTap(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(desc, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.3)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _simpleTile(IconData icon, String title, String sub, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppColors.textSecondary, size: 20),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(sub, style: const TextStyle(fontSize: 11)),
      trailing: const Icon(Icons.open_in_new_rounded, size: 14, color: AppColors.textMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _inputField(TextEditingController ctrl, String hint, IconData icon, {Function(String)? onChanged}) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
      ),
    );
  }

  Widget _loadSelector(int current, Function(int) onSelect) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
      child: DropdownButton<int>(
        value: current,
        underline: const SizedBox(),
        items: [1, 2, 3, 5, 10].map((v) => DropdownMenuItem(value: v, child: Text('$v kW'))).toList(),
        onChanged: (v) => v != null ? onSelect(v) : null,
      ),
    );
  }

  Widget _protectedToggle(bool val, Function(bool) onChanged) {
    return Row(
      children: [
        const Text('Protected Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const Spacer(),
        Switch(value: val, onChanged: onChanged),
      ],
    );
  }

  Widget _calcRow(String label, double val, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Text(_pkrDec.format(val), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
