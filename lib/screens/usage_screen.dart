import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/meter.dart';
import '../services/meter_repository.dart';
import '../theme/app_theme.dart';
import '../utils/animation_utils.dart';

final _dateFmt = DateFormat('dd MMM');
final _fullFmt = DateFormat('dd MMM, hh:mm a');

class UsageScreen extends StatefulWidget {
  const UsageScreen({super.key});

  @override
  State<UsageScreen> createState() => _UsageScreenState();
}

class _UsageScreenState extends State<UsageScreen>
    with SingleTickerProviderStateMixin {
  int _tab = 0; // 0 = Daily, 1 = Weekly
  String? _selectedMeterId; // null = All Meters
  late AnimationController _animController;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _switchTab(int t) {
    setState(() {
      _tab = t;
    });
    _animController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<List<MeterModel>>(
        stream: MeterRepository.instance.watchMeters(),
        builder: (ctx, snap) {
          final meters = snap.data ?? const <MeterModel>[];
          final loading = snap.connectionState == ConnectionState.waiting;

          final selectedMeter = _selectedMeterId == null
              ? null
              : meters.where((m) => m.id == _selectedMeterId).firstOrNull;
          final visibleMeters =
              selectedMeter == null ? meters : [selectedMeter];

          final allLogs = _collectLogs(visibleMeters);

          // Calculate Totals using correct delta logic
          final now = DateTime.now();
          final startOfToday = DateTime(now.year, now.month, now.day);
          final endOfToday = startOfToday.add(const Duration(hours: 23, minutes: 59, seconds: 59));
          final startOfWeek = startOfToday.subtract(const Duration(days: 6));
          final startOfMonth = DateTime(now.year, now.month, 1);

          final totalUnits = visibleMeters.fold<double>(0.0, (s, m) => s + m.consumedUnitsKwh);
          final todayUnits = visibleMeters.fold<double>(0.0, (s, m) => s + m.unitsInPeriod(startOfToday, endOfToday));
          final weekUnits = visibleMeters.fold<double>(0.0, (s, m) => s + m.unitsInPeriod(startOfWeek, now));
          final monthUnits = visibleMeters.fold<double>(0.0, (s, m) => s + m.unitsInPeriod(startOfMonth, now));

          final chartPoints = _buildChartPoints(visibleMeters, _tab);
          final hasChart = chartPoints.length >= 2;

          return FadeTransition(
            opacity: _fadeIn,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildHeader(
                    meters: meters,
                    selectedMeterName: selectedMeter?.name,
                    totalUnits: totalUnits,
                    periodUnits: _tab == 0 ? todayUnits : weekUnits,
                    dailyAverage: monthUnits / 30, // Rough estimate
                    isWeekly: _tab == 1,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverToBoxAdapter(
                  child: _buildMeterSelector(meters),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _TabSelector(value: _tab, onChanged: _switchTab),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverToBoxAdapter(
                  child: _buildChartCard(
                    loading: loading,
                    hasChart: hasChart,
                    chartPoints: chartPoints,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                if (allLogs.isNotEmpty) ...[
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Reading History',
                              style: Theme.of(context).textTheme.titleLarge),
                          Text('${allLogs.length} entries',
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final log = allLogs[allLogs.length - 1 - i];
                          return FadeSlideEntrance(
                            delay: Duration(milliseconds: 50 * i),
                            child: _ReadingTile(log: log, isLatest: i == 0),
                          );
                        },
                        childCount: allLogs.length,
                      ),
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          );
        },
      ),
    );
  }

  List<_ChartPoint> _buildChartPoints(List<MeterModel> meters, int tab) {
    if (tab == 0) {
      // Daily view: Show last 7 days of consumption deltas
      final now = DateTime.now();
      return List.generate(7, (i) {
        final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i));
        final endOfDay = date.add(const Duration(hours: 23, minutes: 59, seconds: 59));

        double dailyUnits = 0;
        for (final m in meters) {
          dailyUnits += m.unitsInPeriod(date, endOfDay);
        }

        return _ChartPoint(
          label: _dateFmt.format(date),
          units: dailyUnits,
          fullLabel: _fullFmt.format(date),
        );
      });
    } else {
      // Weekly view: Show last 4 weeks
      final now = DateTime.now();
      return List.generate(4, (i) {
        final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: (3 - i) * 7 + 6));
        final end = start.add(const Duration(days: 6, hours: 23, minutes: 59));

        double weeklyUnits = 0;
        for (final m in meters) {
          weeklyUnits += m.unitsInPeriod(start, end);
        }

        return _ChartPoint(
          label: 'W${4 - (3 - i)}',
          units: weeklyUnits,
          fullLabel: 'Week of ${_dateFmt.format(start)}',
        );
      });
    }
  }

  List<MeterReadingLog> _collectLogs(List<MeterModel> meters) {
    final logs = <MeterReadingLog>[];
    for (final m in meters) {
      if (_selectedMeterId == null || m.id == _selectedMeterId) {
        logs.addAll(m.readingHistory);
      }
    }
    logs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return logs;
  }

  Widget _buildHeader(
      {required List<MeterModel> meters,
      required String? selectedMeterName,
      required double totalUnits,
      required double periodUnits,
      required double dailyAverage,
      required bool isWeekly}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
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
                  const Text('Electricity Usage',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  Text(
                    _selectedMeterId == null
                        ? 'All Registered Meters'
                        : 'Selected: ${selectedMeterName ?? 'Meter'}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              const CircleAvatar(
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.analytics_rounded,
                      color: Colors.white, size: 20)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                  child: _MetricChip(
                      label: 'TOTAL UNITS',
                      value: '${totalUnits.toInt()} kWh',
                      accent: Colors.white)),
              const SizedBox(width: 8),
              Expanded(
                  child: _MetricChip(
                      label: isWeekly ? 'WEEKLY UNITS' : 'TODAY UNITS',
                      value: '${periodUnits.toInt()} kWh',
                      accent: AppColors.accentGreen)),
              const SizedBox(width: 8),
              Expanded(
                  child: _MetricChip(
                      label: 'DAILY AVG',
                      value: '${dailyAverage.toStringAsFixed(1)} kWh',
                      accent: AppColors.accentOrange)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(
      {required bool loading,
      required bool hasChart,
      required List<_ChartPoint> chartPoints}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Consumption Trend',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textPrimary)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(['Daily', 'Weekly'][_tab],
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : !hasChart
                      ? const Center(
                          child: Text('Add more data points to see trend',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textMuted)))
                      : BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: chartPoints.isEmpty
                                ? 10
                                : chartPoints
                                        .map((e) => e.units)
                                        .reduce((a, b) => a > b ? a : b) *
                                    1.3,
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: 50,
                              getDrawingHorizontalLine: (value) => FlLine(
                                color: Colors.grey.withValues(alpha: 0.05),
                                strokeWidth: 1,
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            barTouchData: BarTouchData(
                              enabled: true,
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipColor: (_) => AppColors.primary,
                                tooltipPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                tooltipBorderRadius: BorderRadius.circular(12),
                                getTooltipItem:
                                    (group, groupIndex, rod, rodIndex) {
                                  final point = chartPoints[groupIndex];
                                  return BarTooltipItem(
                                    '${rod.toY.toInt()} kWh\n',
                                    const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14),
                                    children: [
                                      TextSpan(
                                        text: point.fullLabel,
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 32,
                                  getTitlesWidget: (v, meta) => Text(
                                      v.toInt().toString(),
                                      style: const TextStyle(
                                          fontSize: 9,
                                          color: AppColors.textMuted,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 44,
                                  getTitlesWidget: (v, meta) {
                                    final idx = v.toInt();
                                    if (idx < 0 || idx >= chartPoints.length) {
                                      return const SizedBox();
                                    }

                                    // Skip logic to prevent overlap
                                    final total = chartPoints.length;
                                    int interval = 1;
                                    if (total > 15) {
                                      interval = 4;
                                    } else if (total > 8) {
                                      interval = 2;
                                    }

                                    if (idx % interval != 0 &&
                                        idx != total - 1) {
                                      return const SizedBox();
                                    }

                                    return SideTitleWidget(
                                      meta: meta,
                                      space: 8,
                                      child: Transform.rotate(
                                        angle: -0.5,
                                        child: Text(
                                          chartPoints[idx].label,
                                          style: const TextStyle(
                                            fontSize: 8,
                                            color: AppColors.textMuted,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            barGroups: [
                              for (var i = 0; i < chartPoints.length; i++)
                                BarChartGroupData(
                                  x: i,
                                  barRods: [
                                    BarChartRodData(
                                      toY: chartPoints[i].units,
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.primaryLight,
                                          AppColors.primary
                                              .withValues(alpha: 0.7)
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                      width: chartPoints.length > 10 ? 10 : 16,
                                      borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(6)),
                                      backDrawRodData:
                                          BackgroundBarChartRodData(
                                        show: true,
                                        toY: chartPoints.isEmpty
                                            ? 10
                                            : chartPoints
                                                    .map((e) => e.units)
                                                    .reduce((a, b) =>
                                                        a > b ? a : b) *
                                                1.3,
                                        color: AppColors.background
                                            .withValues(alpha: 0.5),
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
    );
  }

  Widget _buildMeterSelector(List<MeterModel> meters) {
    if (meters.isEmpty) return const SizedBox();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _meterChip(null, 'All Meters'),
          const SizedBox(width: 8),
          ...meters.map((m) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _meterChip(m.id, m.name))),
        ],
      ),
    );
  }

  Widget _meterChip(String? id, String name) {
    final isSelected = _selectedMeterId == id;
    return Semantics(
      button: true,
      selected: isSelected,
      label: name,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() => _selectedMeterId = id);
            _animController.forward(from: 0.0);
          },
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) ...[
                  const Icon(Icons.check_circle_rounded,
                      size: 16, color: Colors.white),
                  const SizedBox(width: 7),
                ],
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabSelector extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _TabSelector({required this.value, required this.onChanged});

  static const _labels = ['Today', 'Weekly'];
  static const _icons = [
    Icons.calendar_view_day_rounded,
    Icons.calendar_view_week_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
          ]),
      child: Row(
        children: List.generate(2, (i) {
          final sel = i == value;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: InkWell(
                onTap: () => onChanged(i),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_icons[i],
                          size: 15,
                          color: sel ? Colors.white : AppColors.textMuted),
                      const SizedBox(width: 6),
                      Text(_labels[i],
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: sel
                                  ? Colors.white
                                  : AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ReadingTile extends StatelessWidget {
  final MeterReadingLog log;
  final bool isLatest;
  const _ReadingTile({required this.log, required this.isLatest});

  @override
  Widget build(BuildContext context) {
    final isReset = log.source.contains('Reset');
    final accentColor = isLatest
        ? AppColors.primary
        : (isReset ? AppColors.accentOrange : AppColors.textMuted);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isLatest
                ? AppColors.primary.withValues(alpha: 0.3)
                : AppColors.border,
            width: isLatest ? 1.5 : 1),
        boxShadow: isLatest
            ? [
                BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(
                isLatest
                    ? Icons.radio_button_checked
                    : (isReset
                        ? Icons.restart_alt_rounded
                        : Icons.history_rounded),
                size: 18,
                color: accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('${log.readingKwh} kWh',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: isLatest
                                ? AppColors.primary
                                : AppColors.textPrimary)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppColors.accentGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text('+${log.consumedUnitsKwh} kWh',
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accentGreen)),
                    ),
                    const Spacer(),
                    if (isLatest)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6)),
                        child: const Text('LATEST',
                            style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                                letterSpacing: 0.5)),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded,
                        size: 11, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Expanded(
                        child: Text(
                            '${DateFormat('EEE, dd MMM yyyy • hh:mm a').format(log.timestamp)}  •  Base: ${log.baseReadingKwh} kWh',
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.textMuted),
                            overflow: TextOverflow.ellipsis)),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.label_outline_rounded,
                        size: 11, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(log.source,
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textMuted)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  const _MetricChip(
      {required this.label, required this.value, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: accent, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _ChartPoint {
  final String label;
  final double units;
  final String fullLabel;
  const _ChartPoint(
      {required this.label, required this.units, required this.fullLabel});
}
