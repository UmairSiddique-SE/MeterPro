import '../lib/models/meter.dart';

void main() {
  print('--- Billing Logic Verification ---');

  // Case 1: 173 Units, 3 kW Load, Protected -> Output ~Rs 3,215
  final case1 = calculateBillBreakdown(173, sanctionedLoad: 3, isProtected: true);
  print('Case 1 (173 Units, 3kW, Protected):');
  print('  Total Bill: Rs ${case1.totalBillPkr.toStringAsFixed(2)}');
  print('  Energy Cost: ${case1.baseEnergyCost}');
  print('  Fixed Charge: ${case1.fixedCharge}');
  print('  Subsidy: ${case1.subsidy}');
  print('  GST: ${case1.salesTax}');
  print('  FPA: ${case1.fuelPriceAdjustment}');

  // Case 2: 187 Units, 2 kW Load, Protected -> Output ~Rs 3,035
  final case2 = calculateBillBreakdown(187, sanctionedLoad: 2, isProtected: true);
  print('\nCase 2 (187 Units, 2kW, Protected):');
  print('  Total Bill: Rs ${case2.totalBillPkr.toStringAsFixed(2)}');
  print('  Energy Cost: ${case2.baseEnergyCost}');
  print('  Fixed Charge: ${case2.fixedCharge}');
  print('  Subsidy: ${case2.subsidy}');
  print('  GST: ${case2.salesTax}');
  print('  FPA: ${case2.fuelPriceAdjustment}');
}
