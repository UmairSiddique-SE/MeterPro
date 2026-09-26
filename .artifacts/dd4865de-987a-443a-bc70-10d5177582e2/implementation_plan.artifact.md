# Implementation Plan - Professional Usage Charts & Actual Reading Events (Daily View)

Refactor the Usage screen (`UsageScreen`) so that the **Daily** view displays chart bars strictly based on **actual reading log events** ("jab jab reading li ho wo nazar ay, all day ki nahi") rather than static calendar days, and ensure consumed units are calculated accurately.

## User Review Required

> [!IMPORTANT]
> - **Daily View Refactor**: In the Daily tab, the consumption chart will plot data points corresponding precisely to the exact timestamps and consumed units of when meter readings were recorded.
> - **Accurate Consumption Calculation**: Ensure `consumedUnitsKwh` for log entries correctly accounts for previous base readings to prevent incorrect large unit numbers (like `+13109 Units`).

## Open Questions

None.

## Proposed Changes

### Models & Usage Screen

#### [MODIFY] [meter.dart](file:///D:/Project/meterpro/lib/models/meter.dart)
- Improve `consumedUnitsKwh` calculation in `MeterReadingLog` so that if `baseReadingKwh` is 0 or less, it falls back gracefully to the previous log reading or meter baseline.

#### [MODIFY] [usage_screen.dart](file:///D:/Project/meterpro/lib/screens/usage_screen.dart)
- Update `_buildChartPoints` for Daily view (`tab == 0`) to collect actual reading logs (`allLogs`) and generate chart points from each recorded reading event (`log.timestamp`, `log.consumedUnitsKwh`).
- For Weekly view (`tab == 1`), maintain clean weekly period grouping.

## Verification Plan

### Automated Tests
- Run `flutter analyze` to ensure zero compilation errors.

### Manual Verification
- Navigate to the Usage screen.
- Verify Daily tab displays bars only for actual reading dates with correct consumed units.
- Verify Weekly tab displays weekly breakdown cleanly.
