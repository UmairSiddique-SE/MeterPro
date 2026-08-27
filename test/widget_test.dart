import 'package:flutter_test/flutter_test.dart';
import 'package:meterunit/models/meter.dart';

void main() {
  test('recalculates bill totals when a reading changes', () {
    final meter = MeterModel.create(
      name: 'Test customer',
      referenceNo: '12345678901234',
      meterNo: 'M12345',
      presentReadingKwh: 1000,
      previousReadingKwh: 900,
    );

    final updated = meter.copyWith(presentReadingKwh: 1050);

    expect(updated.monthlyUnitsKwh, 150);
    expect(updated.monthlyBillPkr, greaterThan(meter.monthlyBillPkr));
    expect(updated.estimatedBillPkr, updated.monthlyBillPkr);
  });

  test('does not allow consumed units to become negative', () {
    final meter = MeterModel.create(
      name: 'Test customer',
      referenceNo: '12345678901234',
      meterNo: 'M12345',
      presentReadingKwh: 900,
      previousReadingKwh: 1000,
    );

    expect(meter.consumedUnitsKwh, 0);
    expect(meter.monthlyUnitsKwh, 0);
  });
}
