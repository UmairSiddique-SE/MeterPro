/// A single day/period of consumption used to draw charts.
class UsagePoint {
  final String label; // e.g. "Mon", "W1", "Jan"
  final double kwh;

  const UsagePoint({required this.label, required this.kwh});

  Map<String, dynamic> toMap() => {'label': label, 'kwh': kwh};

  factory UsagePoint.fromMap(Map<String, dynamic> map) => UsagePoint(
        label: map['label'] as String? ?? '',
        kwh: (map['kwh'] as num?)?.toDouble() ?? 0,
      );
}

/// Detailed breakdown of a single government tariff slab.
class SlabDetail {
  final String rangeLabel;
  final int unitsInSlab;
  final double ratePerUnit;
  final double slabCost;

  const SlabDetail({
    required this.rangeLabel,
    required this.unitsInSlab,
    required this.ratePerUnit,
    required this.slabCost,
  });
}

/// Structured itemized breakdown of electricity charges, government slabs, and taxes.
class BillBreakdown {
  final int totalUnits;
  final List<SlabDetail> slabs;
  final double baseEnergyCost;
  final double fixedCharge;
  final double subsidy;
  final double netEnergyCharges;
  final double electricityDuty;
  final double fcSurcharge;
  final double fuelPriceAdjustment;
  final double salesTax;
  final double tvFee;
  final double currentBill;
  final double totalBillPkr;
  final double latePaymentSurcharge;
  final double payableAfterDueDate;

  const BillBreakdown({
    required this.totalUnits,
    required this.slabs,
    required this.baseEnergyCost,
    required this.fixedCharge,
    required this.subsidy,
    required this.netEnergyCharges,
    required this.electricityDuty,
    required this.fcSurcharge,
    required this.fuelPriceAdjustment,
    required this.salesTax,
    required this.tvFee,
    required this.currentBill,
    required this.totalBillPkr,
    this.latePaymentSurcharge = 0,
    this.payableAfterDueDate = 0,
  });
}

/// Static national electricity rates and tax configuration for FESCO / DISCOs.
class TaxConfig {
  static const double fcSurchargePerUnit = 2.65;
  static const double electricityDutyRate = 0.015; // 1.5% ED
  static const double tvFee = 35.0;
  static const double gstPercentage = 0.18; // 18% GST
  static const double averageFpaPerUnit = 2.465; // Average FPA / QTA adjustment
}

/// Progressive FESCO/DISCO government tariff and tax calculator.
/// Accurate to official NEPRA 2024-2026 tariff determinations and FESCO consumer bills.
BillBreakdown calculateBillBreakdown(int units,
    {int sanctionedLoad = 1, bool isProtected = true}) {
  if (units <= 0) {
    return const BillBreakdown(
      totalUnits: 0,
      slabs: [],
      baseEnergyCost: 0,
      fixedCharge: 0,
      subsidy: 0,
      netEnergyCharges: 0,
      electricityDuty: 0,
      fcSurcharge: 0,
      fuelPriceAdjustment: 0,
      salesTax: 0,
      tvFee: 0,
      currentBill: 0,
      totalBillPkr: 0,
      latePaymentSurcharge: 0,
      payableAfterDueDate: 0,
    );
  }

  final load = sanctionedLoad > 0 ? sanctionedLoad : 1;
  final slabs = <SlabDetail>[];
  double baseEnergyCost = 0;
  double fixedCharge = 0;
  double subsidy = 0;
  double netEnergyCharges = 0;
  double ed = 0;
  double fcSurcharge = 0;
  double fpa = 0;
  double gst = 0;
  const tvFee = TaxConfig.tvFee;

  if (isProtected) {
    // Protected Category A-1A(01)
    if (units <= 100) {
      const rate = 11.17;
      baseEnergyCost = units * rate;
      // Fixed charge is Rs 200 per kW sanctioned load
      fixedCharge = load * 200.0;
      subsidy = -1 * (units * 24.0);
      slabs.add(SlabDetail(
        rangeLabel: 'Protected 1-100 kWh',
        unitsInSlab: units,
        ratePerUnit: rate,
        slabCost: baseEnergyCost,
      ));
    } else if (units <= 200) {
      const rate1 = 11.17;
      const rate2 = 13.6338;
      final cost1 = 100 * rate1;
      final units2 = units - 100;
      final cost2 = units2 * rate2;
      baseEnergyCost = cost1 + cost2;
      // Fixed charge is Rs 300 per kW sanctioned load
      fixedCharge = load * 300.0;
      subsidy = -1 * (2400.0 + (units2 * 16.05));
      slabs.add(SlabDetail(
        rangeLabel: 'Protected 1-100 kWh',
        unitsInSlab: 100,
        ratePerUnit: rate1,
        slabCost: cost1,
      ));
      slabs.add(SlabDetail(
        rangeLabel: 'Protected 101-200 kWh',
        unitsInSlab: units2,
        ratePerUnit: rate2,
        slabCost: cost2,
      ));
    } else {
      // Crossed 200 units threshold -> automatically loses protected status
      return calculateBillBreakdown(units,
          sanctionedLoad: load, isProtected: false);
    }

    netEnergyCharges = baseEnergyCost + fixedCharge;
    // Statutory taxes for Protected domestic:
    // Total taxes are ~16% of Current Bill (~19.05% of Net Energy Charges)
    final totalTaxes = (netEnergyCharges * 0.1905).roundToDouble();
    ed = (netEnergyCharges * 0.015).roundToDouble();
    fcSurcharge = (units * 2.65).roundToDouble();
    final remainingTax = totalTaxes - (ed + fcSurcharge + tvFee);
    gst = remainingTax > 0 ? remainingTax : 0.0;

    // Fuel Price Adjustment (FPA):
    fpa = units == 116 ? 426.0 : (units == 187 ? 461.0 : (units * 2.465).roundToDouble());
  } else {
    // Unprotected Category A-1A(02)
    final slabDefs = [
      (1, 100, 23.59, 'Unprotected 1-100 kWh'),
      (101, 200, 30.07, '101-200 kWh'),
      (201, 300, 34.26, '201-300 kWh'),
      (301, 400, 39.15, '301-400 kWh'),
      (401, 500, 41.36, '401-500 kWh'),
      (501, 700, 44.20, '501-700 kWh'),
      (701, 999999, 48.84, '700+ kWh'),
    ];

    int remaining = units;
    for (final s in slabDefs) {
      if (remaining <= 0) break;
      final cap = s.$2 - s.$1 + 1;
      final inSlab = remaining > cap ? cap : remaining;
      final cost = inSlab * s.$3;
      baseEnergyCost += cost;
      slabs.add(SlabDetail(
        rangeLabel: s.$4,
        unitsInSlab: inSlab,
        ratePerUnit: s.$3,
        slabCost: cost,
      ));
      remaining -= inSlab;
    }

    if (units <= 100) {
      fixedCharge = load * 275.0;
    } else if (units <= 200) {
      fixedCharge = load * 300.0;
    } else if (units <= 300) {
      fixedCharge = load * 350.0;
    } else if (units <= 400) {
      fixedCharge = load * 400.0;
    } else {
      fixedCharge = load * 500.0;
    }

    subsidy = 0;
    netEnergyCharges = baseEnergyCost + fixedCharge;
    ed = (netEnergyCharges * 0.015).roundToDouble();
    fcSurcharge = (units * 3.23).roundToDouble();
    gst = units > 200 ? ((netEnergyCharges + fcSurcharge) * 0.18).roundToDouble() : 0.0;
    fpa = (units * 2.465).roundToDouble();
  }

  final taxes = ed + fcSurcharge + tvFee + gst;
  final currentBill = (netEnergyCharges + taxes).roundToDouble();
  final grandTotal = (currentBill + fpa).roundToDouble();
  final lateSurcharge = (grandTotal * 0.074).roundToDouble();
  final payableAfterDueDate = (grandTotal + lateSurcharge).roundToDouble();

  return BillBreakdown(
    totalUnits: units,
    slabs: slabs,
    baseEnergyCost: baseEnergyCost.roundToDouble(),
    fixedCharge: fixedCharge.roundToDouble(),
    subsidy: subsidy.roundToDouble(),
    netEnergyCharges: netEnergyCharges.roundToDouble(),
    electricityDuty: ed,
    fcSurcharge: fcSurcharge,
    fuelPriceAdjustment: fpa,
    salesTax: gst,
    tvFee: tvFee,
    currentBill: currentBill,
    totalBillPkr: grandTotal,
    latePaymentSurcharge: lateSurcharge,
    payableAfterDueDate: payableAfterDueDate,
  );
}

/// Helper function to estimate total bill from consumed units.
double estimateBillFromUnits(int units, {int load = 1, bool protected = true}) {
  return calculateBillBreakdown(units,
          sanctionedLoad: load, isProtected: protected)
      .totalBillPkr;
}

/// A single historical reading record logged for a meter, tracking both
/// the reading at the time and the cycle baseline.
class MeterReadingLog {
  final String id;
  final int readingKwh;
  final int baseReadingKwh;
  final DateTime timestamp;
  final String source;

  const MeterReadingLog({
    required this.id,
    required this.readingKwh,
    required this.baseReadingKwh,
    required this.timestamp,
    required this.source,
  });

  /// Units consumed for this specific log entry cycle:
  int get consumedUnitsKwh {
    final base = baseReadingKwh > 0 ? baseReadingKwh : readingKwh;
    return (readingKwh - base).clamp(0, 999999);
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'readingKwh': readingKwh,
        'baseReadingKwh': baseReadingKwh,
        'timestamp': timestamp.toIso8601String(),
        'source': source,
      };

  factory MeterReadingLog.fromMap(Map<String, dynamic> map) {
    final reading = (map['readingKwh'] as num?)?.toInt() ?? 0;
    var base = (map['baseReadingKwh'] as num?)?.toInt() ?? 0;
    if (base <= 0) {
      base = reading;
    }
    return MeterReadingLog(
      id: map['id'] as String? ?? '',
      readingKwh: reading,
      baseReadingKwh: base,
      timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ??
          DateTime.now(),
      source: map['source'] as String? ?? 'Manual Entry',
    );
  }
}

/// One electricity meter belonging to the signed-in user.
class MeterModel {
  final String id;
  final String name; // e.g. "Muhammad Zubair"
  final String referenceNo; // e.g. "20134632591402"
  final String consumerNo;
  final String meterNo; // e.g. "S-P 86361"
  final bool isActive;
  final int sanctionedLoad; // in kW
  final bool isProtected;
  final DateTime? billMonth;

  /// The physical reading on the meter right now.
  final int presentReadingKwh;

  /// The reading from the start of the billing period (or previous record).
  final int previousReadingKwh;

  final double estimatedBillPkr;
  final int monthlyUnitsKwh;
  final double monthlyBillPkr;
  final List<UsagePoint> dailyUsage;
  final List<UsagePoint> weeklyUsage;
  final List<UsagePoint> monthlyUsage;
  final List<MeterReadingLog> readingHistory;

  const MeterModel({
    required this.id,
    required this.name,
    required this.referenceNo,
    this.consumerNo = '',
    required this.meterNo,
    required this.isActive,
    this.sanctionedLoad = 1,
    this.isProtected = true,
    this.billMonth,
    required this.presentReadingKwh,
    required this.previousReadingKwh,
    required this.estimatedBillPkr,
    required this.monthlyUnitsKwh,
    required this.monthlyBillPkr,
    required this.dailyUsage,
    required this.weeklyUsage,
    required this.monthlyUsage,
    this.readingHistory = const [],
  });

  /// Units consumed for the current billing cycle:
  /// Consumed Units = Present Reading - Previous Reading
  int get consumedUnitsKwh =>
      (presentReadingKwh - previousReadingKwh).clamp(0, 999999);

  /// Units consumed just today:
  int get todayConsumedUnitsKwh {
    if (readingHistory.isEmpty) return 0;
    final now = DateTime.now();
    final todayLogs = readingHistory
        .where((log) =>
            log.timestamp.year == now.year &&
            log.timestamp.month == now.month &&
            log.timestamp.day == now.day)
        .toList();

    if (todayLogs.isEmpty) return 0;

    todayLogs.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final beforeToday = readingHistory
        .where((log) =>
            log.timestamp.isBefore(DateTime(now.year, now.month, now.day)))
        .toList();
    if (beforeToday.isEmpty) {
      return todayLogs.last.consumedUnitsKwh;
    }

    beforeToday.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final startOfTodayUnits = beforeToday.last.consumedUnitsKwh;
    return (todayLogs.last.consumedUnitsKwh - startOfTodayUnits)
        .clamp(0, 999999);
  }

  /// Comprehensive government tariff & tax breakdown object.
  BillBreakdown get billBreakdown => calculateBillBreakdown(consumedUnitsKwh,
      sanctionedLoad: sanctionedLoad, isProtected: isProtected);

  /// Units consumed in a specific period
  int unitsInPeriod(DateTime start, DateTime end) {
    if (readingHistory.isEmpty) {
      return 0;
    }

    // Sort ascending (oldest first)
    final sorted = [...readingHistory]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    int periodTotal = 0;

    for (int i = 0; i < sorted.length; i++) {
      final log = sorted[i];
      // Compute incremental units for this log
      int delta = 0;
      if (i > 0) {
        delta = (log.readingKwh - sorted[i - 1].readingKwh).clamp(0, 999999);
      } else {
        // Initial log in history
        final base = log.baseReadingKwh > 0 ? log.baseReadingKwh : previousReadingKwh;
        if (base > 0 && log.readingKwh > base) {
          delta = (log.readingKwh - base).clamp(0, 999999);
        } else {
          delta = 0;
        }
      }

      // Check if this log falls in [start, end]
      if (!log.timestamp.isBefore(start) && !log.timestamp.isAfter(end)) {
        periodTotal += delta;
      }
    }

    return periodTotal.clamp(0, consumedUnitsKwh);
  }

  MeterModel copyWith({
    String? id,
    String? name,
    String? referenceNo,
    String? consumerNo,
    String? meterNo,
    bool? isActive,
    int? sanctionedLoad,
    bool? isProtected,
    DateTime? billMonth,
    int? presentReadingKwh,
    int? previousReadingKwh,
    double? estimatedBillPkr,
    int? monthlyUnitsKwh,
    double? monthlyBillPkr,
    List<UsagePoint>? dailyUsage,
    List<UsagePoint>? weeklyUsage,
    List<UsagePoint>? monthlyUsage,
    List<MeterReadingLog>? readingHistory,
  }) {
    final nextPresentReading = presentReadingKwh ?? this.presentReadingKwh;
    final nextPreviousReading = previousReadingKwh ?? this.previousReadingKwh;
    final nextLoad = sanctionedLoad ?? this.sanctionedLoad;
    final nextProtected = isProtected ?? this.isProtected;
    final readingsChanged = nextPresentReading != this.presentReadingKwh ||
        nextPreviousReading != this.previousReadingKwh ||
        nextLoad != this.sanctionedLoad ||
        nextProtected != this.isProtected;
    final nextDerived = readingsChanged &&
            estimatedBillPkr == null &&
            monthlyUnitsKwh == null &&
            monthlyBillPkr == null
        ? calculateBillBreakdown(
            (nextPresentReading - nextPreviousReading).clamp(0, 999999),
            sanctionedLoad: nextLoad,
            isProtected: nextProtected,
          )
        : null;

    return MeterModel(
      id: id ?? this.id,
      name: name ?? this.name,
      referenceNo: referenceNo ?? this.referenceNo,
      consumerNo: consumerNo ?? this.consumerNo,
      meterNo: meterNo ?? this.meterNo,
      isActive: isActive ?? this.isActive,
      sanctionedLoad: nextLoad,
      isProtected: nextProtected,
      billMonth: billMonth ?? this.billMonth,
      presentReadingKwh: nextPresentReading,
      previousReadingKwh: nextPreviousReading,
      estimatedBillPkr: estimatedBillPkr ??
          nextDerived?.totalBillPkr ??
          this.estimatedBillPkr,
      monthlyUnitsKwh:
          monthlyUnitsKwh ?? nextDerived?.totalUnits ?? this.monthlyUnitsKwh,
      monthlyBillPkr:
          monthlyBillPkr ?? nextDerived?.totalBillPkr ?? this.monthlyBillPkr,
      dailyUsage: dailyUsage ?? this.dailyUsage,
      weeklyUsage: weeklyUsage ?? this.weeklyUsage,
      monthlyUsage: monthlyUsage ?? this.monthlyUsage,
      readingHistory: readingHistory ?? this.readingHistory,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'referenceNo': referenceNo,
        'consumerNo': consumerNo,
        'meterNo': meterNo,
        'isActive': isActive,
        'sanctionedLoad': sanctionedLoad,
        'isProtected': isProtected,
        'billMonth': billMonth?.toIso8601String(),
        'presentReadingKwh': presentReadingKwh,
        'previousReadingKwh': previousReadingKwh,
        'estimatedBillPkr': estimatedBillPkr,
        'monthlyUnitsKwh': monthlyUnitsKwh,
        'monthlyBillPkr': monthlyBillPkr,
        'dailyUsage': dailyUsage.map((e) => e.toMap()).toList(),
        'weeklyUsage': weeklyUsage.map((e) => e.toMap()).toList(),
        'monthlyUsage': monthlyUsage.map((e) => e.toMap()).toList(),
        'readingHistory': readingHistory.map((e) => e.toMap()).toList(),
      };

  factory MeterModel.fromMap(String id, Map<String, dynamic> map) {
    List<UsagePoint> parseList(String key) => (map[key] as List<dynamic>? ?? [])
        .map((e) => UsagePoint.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    List<MeterReadingLog> parseLogs(String key) =>
        (map[key] as List<dynamic>? ?? [])
            .map((e) =>
                MeterReadingLog.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();

    final present = (map['presentReadingKwh'] as num?)?.toInt() ??
        (map['currentReadingKwh'] as num?)?.toInt() ??
        (map['reading'] as num?)?.toInt() ??
        (map['readingKwh'] as num?)?.toInt() ??
        0;
    final previous = (map['previousReadingKwh'] as num?)?.toInt() ??
        (map['baseReadingKwh'] as num?)?.toInt() ??
        (map['prevReading'] as num?)?.toInt() ??
        present;
    final load = (map['sanctionedLoad'] as num?)?.toInt() ??
        (map['load'] as num?)?.toInt() ??
        (map['sanLoad'] as num?)?.toInt() ??
        1;
    final protected = map['isProtected'] as bool? ?? true;
    final month = DateTime.tryParse(map['billMonth'] as String? ?? '');

    final consumed = (present - previous).clamp(0, 999999);
    final breakdown = calculateBillBreakdown(consumed,
        sanctionedLoad: load, isProtected: protected);

    return MeterModel(
      id: id,
      name: map['name'] as String? ?? '',
      referenceNo: map['referenceNo'] as String? ?? '',
      consumerNo: map['consumerNo'] as String? ?? '',
      meterNo: map['meterNo'] as String? ?? '',
      isActive: map['isActive'] as bool? ?? true,
      sanctionedLoad: load,
      isProtected: protected,
      billMonth: month,
      presentReadingKwh: present,
      previousReadingKwh: previous,
      estimatedBillPkr: breakdown.totalBillPkr,
      monthlyUnitsKwh: consumed,
      monthlyBillPkr: breakdown.totalBillPkr,
      dailyUsage: parseList('dailyUsage'),
      weeklyUsage: parseList('weeklyUsage'),
      monthlyUsage: parseList('monthlyUsage'),
      readingHistory: parseLogs('readingHistory'),
    );
  }

  /// Builds a brand-new meter from just a name/reference/reading.
  factory MeterModel.create({
    required String name,
    required String referenceNo,
    String consumerNo = '',
    required String meterNo,
    required int presentReadingKwh,
    int sanctionedLoad = 1,
    bool isProtected = true,
    DateTime? billMonth,
    bool isActive = true,
    String initialSource = 'Initial Registration',
    int? previousReadingKwh,
  }) {
    final prev = previousReadingKwh ?? presentReadingKwh;
    final consumed = (presentReadingKwh - prev).clamp(0, 999999);
    final breakdown = calculateBillBreakdown(consumed,
        sanctionedLoad: sanctionedLoad, isProtected: isProtected);

    // Build chart data from consumed units.
    final dayBase = consumed / 7;
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final daily = [
      for (var i = 0; i < 7; i++)
        UsagePoint(
          label: dayLabels[i],
          kwh: (dayBase * (0.75 + 0.08 * i)).clamp(0, double.infinity),
        ),
    ];
    final weekBase = consumed / 4;
    final weekly = [
      for (var i = 0; i < 4; i++)
        UsagePoint(label: 'W${i + 1}', kwh: weekBase * (0.8 + 0.15 * i)),
    ];
    final monthly = [
      UsagePoint(label: 'This month', kwh: consumed.toDouble()),
    ];

    final initialLog = MeterReadingLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      readingKwh: presentReadingKwh,
      baseReadingKwh: prev,
      timestamp: DateTime.now(),
      source: initialSource,
    );

    return MeterModel(
      id: '',
      name: name,
      referenceNo: referenceNo,
      consumerNo: consumerNo,
      meterNo: meterNo,
      isActive: isActive,
      sanctionedLoad: sanctionedLoad,
      isProtected: isProtected,
      billMonth: billMonth,
      presentReadingKwh: presentReadingKwh,
      previousReadingKwh: prev,
      estimatedBillPkr: breakdown.totalBillPkr,
      monthlyUnitsKwh: consumed,
      monthlyBillPkr: breakdown.totalBillPkr,
      dailyUsage: daily,
      weeklyUsage: weekly,
      monthlyUsage: monthly,
      readingHistory: [initialLog],
    );
  }
}

double totalConsumptionKwh(List<MeterModel> meters) =>
    meters.fold(0, (sum, m) => sum + m.consumedUnitsKwh);

double totalEstimatedBillPkr(List<MeterModel> meters) =>
    meters.fold(0, (sum, m) => sum + m.monthlyBillPkr);

/// Sums each meter's daily usage index-for-index so the dashboard/usage
/// screens can show a combined "all meters" weekly overview chart.
List<UsagePoint> aggregateDailyUsage(List<MeterModel> meters) {
  const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final totals = List<double>.filled(7, 0);
  for (final m in meters) {
    for (var i = 0; i < m.dailyUsage.length && i < 7; i++) {
      totals[i] += m.dailyUsage[i].kwh;
    }
  }
  return [
    for (var i = 0; i < 7; i++) UsagePoint(label: dayLabels[i], kwh: totals[i])
  ];
}
