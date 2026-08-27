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
  final double electricityDuty;
  final double fcSurcharge;
  final double fuelPriceAdjustment;
  final double salesTax;
  final double tvFee;
  final double totalBillPkr;

  const BillBreakdown({
    required this.totalUnits,
    required this.slabs,
    required this.baseEnergyCost,
    required this.fixedCharge,
    required this.subsidy,
    required this.electricityDuty,
    required this.fcSurcharge,
    required this.fuelPriceAdjustment,
    required this.salesTax,
    required this.tvFee,
    required this.totalBillPkr,
  });
}

/// Static national electricity rates and tax configuration.
class TaxConfig {
  static const double fcSurchargePerUnit = 0.428;
  static const double electricityDuty = 25.0; // Fixed as per prompt
  static const double tvFee = 35.0;
  static const double gstPercentage = 0.1871;
  static const double averageFpaPerUnit = 0.355;
}

/// Progressive FESCO/DISCO government tariff and tax calculator.
BillBreakdown calculateBillBreakdown(int units,
    {int sanctionedLoad = 1, bool isProtected = true}) {
  if (units <= 0) {
    return const BillBreakdown(
      totalUnits: 0,
      slabs: [],
      baseEnergyCost: 0,
      fixedCharge: 0,
      subsidy: 0,
      electricityDuty: 0,
      fcSurcharge: 0,
      fuelPriceAdjustment: 0,
      salesTax: 0,
      tvFee: 0,
      totalBillPkr: 0,
    );
  }

  final List<(int, int, double, String)> slabDefinitions;

  if (isProtected) {
    slabDefinitions = [
      (1, 100, 10.54, 'Protected 0-100 kWh'),
      (101, 200, 11.5822, 'Protected 101-200 kWh'),
    ];
  } else {
    // Standard Unprotected Tariff Slabs
    slabDefinitions = [
      (1, 100, 13.48, 'Unprotected 1-100 kWh'),
      (101, 200, 18.95, '101-200 kWh'),
      (201, 300, 23.59, '201-300 kWh'),
      (301, 400, 30.28, '301-400 kWh'),
      (401, 500, 35.24, '401-500 kWh'),
      (501, 700, 38.65, '501-700 kWh'),
      (701, 999999, 42.00, '700+ kWh'),
    ];
  }

  final slabs = <SlabDetail>[];
  double energyCost = 0;
  int remainingUnits = units;

  for (final def in slabDefinitions) {
    final start = def.$1;
    final end = def.$2;
    final rate = def.$3;
    final label = def.$4;

    final slabCapacity = end - start + 1;
    if (remainingUnits > 0) {
      final unitsInThisSlab =
          remainingUnits > slabCapacity ? slabCapacity : remainingUnits;
      final cost = unitsInThisSlab * rate;
      energyCost += cost;
      slabs.add(SlabDetail(
        rangeLabel: label,
        unitsInSlab: unitsInThisSlab,
        ratePerUnit: rate,
        slabCost: cost,
      ));
      remainingUnits -= unitsInThisSlab;
    }
  }

  // Handle excess units for Protected category (though prompt implies max 200 for protected logic provided)
  if (isProtected && remainingUnits > 0) {
    const excessRate = 23.59; // Fallback to unprotected 201-300 rate if exceeds
    final cost = remainingUnits * excessRate;
    energyCost += cost;
    slabs.add(SlabDetail(
      rangeLabel: 'Excess units (Unprotected)',
      unitsInSlab: remainingUnits,
      ratePerUnit: excessRate,
      slabCost: cost,
    ));
  }

  // Fixed Charge Logic
  double fixedCharge = 600.0;
  if (isProtected && units > 100 && sanctionedLoad >= 3) {
    fixedCharge = 900.0;
  }

  // Subsidy Logic
  double subsidy = 0.0;
  if (isProtected && units > 100 && units <= 200) {
    subsidy = -344.0;
  }

  final netEnergyCharges = energyCost + fixedCharge + subsidy;

  const electricityDuty = TaxConfig.electricityDuty;
  final fcSurcharge = units * TaxConfig.fcSurchargePerUnit;
  final fpa = units * TaxConfig.averageFpaPerUnit;
  const tvFee = TaxConfig.tvFee;

  final taxableAmount = netEnergyCharges;
  final salesTax = taxableAmount * TaxConfig.gstPercentage;

  final totalBill =
      netEnergyCharges + electricityDuty + fcSurcharge + fpa + salesTax + tvFee;

  return BillBreakdown(
    totalUnits: units,
    slabs: slabs,
    baseEnergyCost: energyCost,
    fixedCharge: fixedCharge,
    subsidy: subsidy,
    electricityDuty: electricityDuty,
    fcSurcharge: fcSurcharge,
    fuelPriceAdjustment: fpa,
    salesTax: salesTax,
    tvFee: tvFee,
    totalBillPkr: totalBill,
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
  int get consumedUnitsKwh => (readingKwh - baseReadingKwh).clamp(0, 999999);

  Map<String, dynamic> toMap() => {
        'id': id,
        'readingKwh': readingKwh,
        'baseReadingKwh': baseReadingKwh,
        'timestamp': timestamp.toIso8601String(),
        'source': source,
      };

  factory MeterReadingLog.fromMap(Map<String, dynamic> map) {
    final reading = (map['readingKwh'] as num?)?.toInt() ?? 0;
    final base = (map['baseReadingKwh'] as num?)?.toInt() ?? reading;
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
    if (readingHistory.isEmpty) return 0;

    // Sort ascending for easier comparison
    final sorted = [...readingHistory]..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Find the last reading before or at the start of the period
    final beforeLogs = sorted.where((l) => !l.timestamp.isAfter(start)).toList();
    final startReading = beforeLogs.isEmpty ? previousReadingKwh : beforeLogs.last.readingKwh;

    // Find the last reading within the period
    final withinLogs = sorted.where((l) => !l.timestamp.isBefore(start) && !l.timestamp.isAfter(end)).toList();
    if (withinLogs.isEmpty) return 0;

    return (withinLogs.last.readingKwh - startReading).clamp(0, 999999);
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
