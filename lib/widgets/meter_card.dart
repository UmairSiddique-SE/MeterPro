import 'package:fl_chart/fl_chart.dart';
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
    return ScaleTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
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
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: meter.isActive ? AppColors.accentGreen : Colors.grey,
                    shape: BoxShape.circle,
                    boxShadow: [
                      if (meter.isActive)
                        BoxShadow(
                          color: AppColors.accentGreen.withValues(alpha: 0.4),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                    ],
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
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Weekly Trend',
                  style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMuted),
                ),
                if (meter.readingHistory.isNotEmpty)
                  Text(
                    'Last: ${DateFormat('hh:mm a').format(meter.readingHistory.last.timestamp)}',
                    style: const TextStyle(
                        fontSize: 8, color: AppColors.textMuted),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 42,
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => AppColors.primary,
                      tooltipPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      tooltipBorderRadius: BorderRadius.circular(8),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${rod.toY.toInt()} kWh',
                          const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ),
                  barGroups: [
                    if (meter.dailyUsage.isEmpty)
                      for (int i = 0; i < 7; i++)
                        BarChartGroupData(x: i, barRods: [
                          BarChartRodData(
                            toY: 0,
                            width: 6,
                            borderRadius: BorderRadius.circular(10),
                            backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: 10,
                                color: const Color(0xCCF4F6FB)),
                          )
                        ])
                    else
                      for (int i = 0; i < meter.dailyUsage.take(7).length; i++)
                        BarChartGroupData(x: i, barRods: [
                          BarChartRodData(
                            toY: meter.dailyUsage[i].kwh,
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primaryLight,
                                AppColors.primary.withValues(alpha: 0.8)
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            width: 6,
                            borderRadius: BorderRadius.circular(10),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: (meter.dailyUsage
                                      .map((e) => e.kwh)
                                      .fold(1.0, (a, b) => a > b ? a : b)) *
                                  1.2,
                              color: const Color(0xCCF4F6FB),
                            ),
                          ),
                        ]),
                  ],
                ),
              ),
            ),
            const Spacer(),
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
                        child: Text(
                          '${meter.monthlyUnitsKwh}',
                          style: const TextStyle(
                              fontSize: 22,
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
                              fontSize: 14,
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
