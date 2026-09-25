# Implementation Plan - Meter Card Redesign on Main Screen

Remove "Read" and "Used" statistics, remove the "Weekly Trend" chart, and replace them with the last 5 readings list while emphasizing the latest "last seen" reading prominently on each meter card on the main screen.

## User Review Required

> [!IMPORTANT]
> - **Main Screen UI Changes**: On the main screen meter cards (`MeterCard`), "Read: ... kWh" and "Used: ... kWh" will be removed.
> - **Weekly Trend Removal**: The "Weekly Trend" header and `BarChart` will be removed.
> - **Last 5 Readings & Last Seen**: A list of the last up to 5 readings from `readingHistory` will be displayed, with the most recent ("last seen") reading highlighted prominently.

## Open Questions

None. The requirements are clear from the user request in Urdu/Roman Urdu.

## Proposed Changes

### Meter Card & Dashboard UI

#### [MODIFY] [meter_card.dart](file:///D:/Project/meterpro/lib/widgets/meter_card.dart)
- Remove `Read:` and `Used:` row.
- Remove `Weekly Trend` label and `BarChart`.
- Add a section displaying the last 5 entries from `meter.readingHistory` (using `meter.readingHistory.reversed.take(5)`).
- Highlight the most recent reading ("last seen") prominently (bold font, accent color/badge).
- Keep the bottom row showing Monthly Units (kWh) and Estimated Bill (Pkr).

#### [MODIFY] [dashboard_screen.dart](file:///D:/Project/meterpro/lib/screens/dashboard_screen.dart)
- Adjust `childAspectRatio` in `GridView.builder` for the meter cards if necessary to accommodate the last 5 readings list cleanly.

## Verification Plan

### Automated Tests
- Build and run the app or run widget tests if available.

### Manual Verification
- Deploy to device/emulator and verify on the main screen:
  1. "Read" and "Used" labels are removed from meter cards.
  2. Weekly Trend chart is removed.
  3. Last 5 readings are listed for each meter.
  4. The last seen reading is highlighted clearly and prominently.
