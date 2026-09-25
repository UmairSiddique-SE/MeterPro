import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/meter.dart';
import '../theme/app_theme.dart';
import '../utils/animation_utils.dart';

final _pkr =
    NumberFormat.currency(locale: 'en_US', symbol: 'Rs', decimalDigits: 0);

class MeterCard extends StatelessWidget {
  final MeterModel meter;
  final VoidCallback onTap;

  const MeterCard({super.key, required this.meter, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final recentLogs = meter.readingHistory.reversed.take(5).toList();

    return ScaleTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: AppColors.border.withValues(alpha: 0.6), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    meter.name,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                meter.isActive
                    ? const PulsingStatusDot(
                        color: AppColors.accentGreen, size: 8)
                    : Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'SN: ${meter.meterNo}',
              style: TextStyle(
                  color: AppColors.textMuted.withValues(alpha: 0.8),
                  fontSize: 9,
                  letterSpacing: 0.3,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Last 5 Readings',
              style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMuted),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: recentLogs.isEmpty
                  ? const Center(
                      child: Text('No readings yet',
                          style: TextStyle(fontSize: 9, color: AppColors.textMuted)),
                    )
                  : ListView.builder(
                      physics: const ClampingScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: recentLogs.length,
                      itemBuilder: (context, index) {
                        final log = recentLogs[index];
                        final isLatest = index == 0;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 3),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: isLatest
                                ? AppColors.primary.withValues(alpha: 0.08)
                                : Colors.grey.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(6),
                            border: isLatest
                                ? Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1)
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  if (isLatest) ...[
                                    Container(
                                      width: 4,
                                      height: 4,
                                      decoration: const BoxDecoration(
                                        color: AppColors.accentGreen,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                  ],
                                  Text(
                                    DateFormat('dd MMM, hh:mm a').format(log.timestamp),
                                    style: TextStyle(
                                      fontSize: 7.5,
                                      fontWeight: isLatest ? FontWeight.bold : FontWeight.w500,
                                      color: isLatest ? AppColors.primary : AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${log.readingKwh} kWh',
                                style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: isLatest ? FontWeight.w900 : FontWeight.w700,
                                    color: isLatest ? AppColors.primary : AppColors.textPrimary),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: AnimatedNumberText(
                          value: meter.monthlyUnitsKwh,
                          formatter: (v) => v.toStringAsFixed(
                              v.truncateToDouble() == v ? 0 : 1),
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              height: 1,
                              color: AppColors.textPrimary),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Units (kWh)',
                        style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          _pkr.format(meter.monthlyBillPkr),
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accentOrange),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Bill',
                              style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted
                                      .withValues(alpha: 0.7))),
                          const SizedBox(width: 2),
                          const Icon(Icons.chevron_right_rounded,
                              size: 12, color: AppColors.textMuted),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
