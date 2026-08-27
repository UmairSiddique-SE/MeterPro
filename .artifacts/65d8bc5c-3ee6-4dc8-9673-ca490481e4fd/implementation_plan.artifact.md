# Implementation Plan - Advanced FESCO Integration & Smart Matching

The goal is to provide a specialized FESCO-only experience that accurately fetches consumer data (Name, Reading, Meter No) from the official PITC website and ensures the Smart Scanner only accepts readings from the correct physical meter.

## User Review Required

> [!IMPORTANT]
> - **FESCO Exclusive**: All other companies (LESCO, etc.) will be removed.
> - **Data Accuracy**: I will improve the scraper to find "Muhammad Zubair" and other real details. If auto-fetch fails, all fields will be fully editable.
> - **Meter Number Matching**: I am adding a "Meter No" field. During scanning, the app will check this number against the physical meter to prevent errors.
> - **Bill Calculation**: I will attempt to fetch real-time tariff rates from the bill page to ensure the "100 units" price logic is accurate.

## Proposed Changes

### [Data Model Update]

#### [MODIFY] [meter.dart](file:///C:/Users/Pc/Downloads/meterunit_flutter_app%20(1)/meterunit/lib/models/meter.dart)
- Add `meterNo` (serial number) to `MeterModel`.
- Update `calculateBillBreakdown` to allow custom rates if fetched from the bill.

### [Direct FESCO Scraper]

#### [MODIFY] [add_meter_screen.dart](file:///C:/Users/Pc/Downloads/meterunit_flutter_app%20(1)/meterunit/lib/screens/add_meter_screen.dart)
- **Remove Options**: Strip out everything not related to FESCO.
- **Robust Scraper**: Update Regex to handle the PITC HTML structure seen in your screenshot:
    - `NAME & ADDRESS` -> Name
    - `METER NO` -> Serial Number
    - `PRESENT READING` -> Baseline Reading
- **Price Logic**: Look for `TARIFF` and tax cells to refine bill estimates.
- **Manual Overrides**: Ensure the "Verify" section has text fields for Name, Reference No, Meter No, and Reading.

### [Scanner Enhancements]

#### [MODIFY] [camera_scanner_screen.dart](file:///C:/Users/Pc/Downloads/meterunit_flutter_app%20(1)/meterunit/lib/screens/camera_scanner_screen.dart)
- **Validation**: Compare scanned text against `meterNo` instead of `referenceNo` for better accuracy (physical meters usually show serial numbers, not bill references).
- **Manual Button**: Add a "Manual Entry" button to the bottom bar for quick override.

## Verification Plan

### Manual Verification
1.  **Direct Fetch**: Enter `20134632591402`. Verify "Muhammad Zubair" and the correct Meter No appear.
2.  **Edit Fetch**: Manually change "Muhammad Zubair" to a nickname. Save and verify.
3.  **Smart Matching**: Try to scan a meter with a different Serial Number. Verify the scanner stays Red.
4.  **Manual Scanner**: Tap "Manual" and type a reading. Verify it saves.
