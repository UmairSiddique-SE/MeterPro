# Implementation Plan - Standardized UI & Enhanced Scanning

This plan focuses on making the app's key screens (Add Meter, Meter Details, and Usage) professional and standard, while significantly improving the OCR data extraction for FESCO bills.

## User Review Required

> [!IMPORTANT]
> - "Scan Meter" button will be renamed to **"Scan Bill"** in the registration flow.
> - The graph in **Meter Details** will be converted to a clean **Column/Bar Chart** or simplified for better aesthetics.
> - **Usage Screen** will be redesigned to be more "aesthetic" and simple, focusing on key insights.

## Proposed Changes

### 1. OCR Service Enhancements

#### [MODIFY] [ocr_service.dart](file:///C:/Users/Pc/Downloads/meterunit_flutter_app%20(1)/meterunit/lib/services/ocr_service.dart)
- Update `OCRScanResult` to explicitly handle `meterNo`.
- Refine extraction logic to better isolate Name, Reference (14 digits), and Meter No from FESCO bills.
- Add logic to ignore labels (like "REFERENCE NO") and take the value immediately following or near them.

### 2. Add Meter Screen Polish

#### [MODIFY] [add_meter_screen.dart](file:///C:/Users/Pc/Downloads/meterunit_flutter_app%20(1)/meterunit/lib/screens/add_meter_screen.dart)
- Rename UI labels from "Scan Meter" to **"Scan Bill"**.
- Ensure `_onScanResult` maps all fields: Consumer Name, Reference Number, Meter Number, and Present Reading.
- Standardize the form layout with better spacing and professional typography.

### 3. Meter Detail Screen Standardizing

#### [MODIFY] [meter_detail_screen.dart](file:///C:/Users/Pc/Downloads/meterunit_flutter_app%20(1)/meterunit/lib/screens/meter_detail_screen.dart)
- Convert the unit progression line chart to a clean **Bar/Column Chart**.
- Simplify the header and metric cards for a "standard" professional look.
- Improve the logic for calculating "Today's Consumption" and displaying it.

### 4. Usage Screen Redesign

#### [MODIFY] [usage_screen.dart](file:///C:/Users/Pc/Downloads/meterunit_flutter_app%20(1)/meterunit/lib/screens/usage_screen.dart)
- Simplify the layout to be more "aesthetic" (minimalist and focused).
- Focus on showing total consumption and estimated costs with larger, clearer typography.
- Standardize the charts to match the new Bar Chart style.

## Verification Plan

### Manual Verification
1. **Scanning**:
   - Register a new meter using "Scan Bill".
   - Verify all 4 fields (Name, Ref, Meter No, Reading) are extracted and pre-filled accurately.
2. **Visual Audit**:
   - Check `MeterDetailScreen` for the new Bar Chart and standardized layout.
   - Check `UsageScreen` for simplicity and "aesthetic" appeal.
   - Ensure "Present Reading" is correctly updated after scanning in the details screen.
