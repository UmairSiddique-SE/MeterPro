import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Get last 3 readings in chronological order (oldest to newest)
    final allLogs = meter.readingHistory;
    final latestTime = allLogs.isNotEmpty
        ? allLogs.first.timestamp
        : (meter.billMonth ?? DateTime.now());

    // Take up to last 3 readings
    final recentLogsDesc = allLogs.take(3).toList();
    final recentLogsAsc = recentLogsDesc.reversed.toList();

    // Compute consumed units for each bar
    final bars = <_TrendBarItem>[];
    for (int i = 0; i < recentLogsAsc.length; i++) {
      final log = recentLogsAsc[i];
      int units = 0;
      final fullIdx = allLogs.indexOf(log);
      if (fullIdx != -1 && fullIdx < allLogs.length - 1) {
        units = (log.readingKwh - allLogs[fullIdx + 1].readingKwh).clamp(0, 999999);
      } else {
        final base = log.baseReadingKwh > 0 ? log.baseReadingKwh : meter.previousReadingKwh;
        if (base > 0 && log.readingKwh > base) {
          units = (log.readingKwh - base).clamp(0, 999999);
        } else {
          units = meter.consumedUnitsKwh > 0 ? meter.consumedUnitsKwh : 0;
        }
      }

      bars.add(_TrendBarItem(
        units: units,
        label: DateFormat('dd/MM').format(log.timestamp),
        time: DateFormat('hh:mm a').format(log.timestamp),
        reading: log.readingKwh,
      ));
    }

    final maxUnits = bars.isEmpty
        ? 1.0
        : bars.map((b) => b.units.toDouble()).fold(1.0, (a, b) => a > b ? a : b);

    return ScaleTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.border.withValues(alpha: 0.7),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Meter Name + Active Status Dot
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    meter.name,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                meter.isActive
                    ? const PulsingStatusDot(color: AppColors.accentGreen, size: 8)
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
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 9,
                letterSpacing: 0.3,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 10),

            // Trend Label & Last Reading Time
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Weekly Trend',
                  style: GoogleFonts.inter(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  'Last: ${DateFormat('dd MMM').format(latestTime)}',
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // ── Mini Trend Graph with Last Readings ──
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurface2.withValues(alpha: 0.5)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: bars.isEmpty
                    ? Center(
                        child: Text(
                          'No readings yet',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final trackHeight =
                              (constraints.maxHeight - 26).clamp(16.0, 42.0);

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: List.generate(
                              3,
                              (index) {
                                if (index < bars.length) {
                                  final item = bars[index];
                                  final ratio = maxUnits > 0
                                      ? (item.units / maxUnits).clamp(0.18, 1.0)
                                      : 0.2;
                                  final isLatest = index == bars.length - 1;

                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      // Unit value label
                                      Text(
                                        '+${item.units}',
                                        style: GoogleFonts.inter(
                                          fontSize: 7.5,
                                          fontWeight: FontWeight.w800,
                                          color: isLatest
                                              ? AppColors.primary
                                              : (isDark
                                                  ? AppColors.darkTextSecondary
                                                  : AppColors
                                                      .lightTextSecondary),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      // Bar capsule track
                                      Container(
                                        width: 14,
                                        height: trackHeight,
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? AppColors.darkSurface3
                                              : const Color(0xFFE2E8F0),
                                          borderRadius:
                                              BorderRadius.circular(7),
                                        ),
                                        alignment: Alignment.bottomCenter,
                                        child: Container(
                                          width: 14,
                                          height: (trackHeight * ratio)
                                              .clamp(4.0, trackHeight),
                                          decoration: BoxDecoration(
                                            gradient: isLatest
                                                ? AppColors.blueGradient
                                                : LinearGradient(
                                                    begin: Alignment.topCenter,
                                                    end:
                                                        Alignment.bottomCenter,
                                                    colors: [
                                                      AppColors.primaryLight
                                                          .withValues(
                                                              alpha: 0.8),
                                                      AppColors.primary
                                                          .withValues(
                                                              alpha: 0.6),
                                                    ],
                                                  ),
                                            borderRadius:
                                                BorderRadius.circular(7),
                                            boxShadow: isLatest
                                                ? [
                                                    BoxShadow(
                                                      color: AppColors.primary
                                                          .withValues(
                                                              alpha: 0.3),
                                                      blurRadius: 4,
                                                      offset:
                                                          const Offset(0, 2),
                                                    )
                                                  ]
                                                : null,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      // Date label
                                      Text(
                                        item.label,
                                        style: GoogleFonts.inter(
                                          fontSize: 7,
                                          fontWeight: isLatest
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: isLatest
                                              ? AppColors.primary
                                              : AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  );
                                } else {
                                  // Filler empty track
                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      const Text('',
                                          style: TextStyle(fontSize: 7.5)),
                                      const SizedBox(height: 2),
                                      Container(
                                        width: 14,
                                        height: trackHeight,
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? AppColors.darkSurface3
                                                  .withValues(alpha: 0.4)
                                              : const Color(0xFFEDF2F7),
                                          borderRadius:
                                              BorderRadius.circular(7),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '--',
                                        style: GoogleFonts.inter(
                                          fontSize: 7,
                                          color: AppColors.textMuted
                                              .withValues(alpha: 0.4),
                                        ),
                                      ),
                                    ],
                                  );
                                }
                              },
                            ),
                          );
                        },
                      ),
              ),
            ),

            const SizedBox(height: 8),

            // Bottom Section: Units on left, Estimated Bill on right
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
                          value: meter.consumedUnitsKwh,
                          formatter: (v) => v.toInt().toString(),
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            height: 1,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Units (kWh)',
                        style: GoogleFonts.inter(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
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
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accentOrange,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Bill',
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
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

class _TrendBarItem {
  final int units;
  final String label;
  final String time;
  final int reading;

  const _TrendBarItem({
    required this.units,
    required this.label,
    required this.time,
    required this.reading,
  });
}
