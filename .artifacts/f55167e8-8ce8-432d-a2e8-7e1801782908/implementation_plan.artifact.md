# Implementation Plan - Enhanced "Add Meter" UI & Stateful Bill Scanning

Implement a professional tabbed interface for adding meters and a stateful, sequential camera scanner that provides clear visual feedback during bill detection.

## User Review Required

> [!IMPORTANT]
> - **Tabbed UI**: The `AddMeterScreen` will now feature a toggle between "Scan Bill" and "Manual Entry" as seen in the requested style.
> - **Stateful Viewfinder**: The camera scanner will change the viewfinder color (Red -> Green) as it sequentially identifies the Date, Reference Number, and other bill details.
> - **Sequential Logic**: The scanner will strictly follow the order: Date/Month Verification -> Reference Number -> Remaining Details.

## Proposed Changes

### [Add Meter Screen]

#### [MODIFY] [add_meter_screen.dart](file:///C:/Users/Pc/Downloads/meterunit_flutter_app/meterunit/lib/screens/add_meter_screen.dart)
- Implement a `DefaultTabController` or custom state-based toggle for "Scan Bill" and "Manual Entry".
- **Scan Bill Tab**:
    - Show a preview illustration with a stylized viewfinder.
    - Add descriptive text about aligning the FESCO bill.
    - Add a prominent "Start Scanning" button.
- **Manual Entry Tab**:
    - Include all existing fields.
    - [NEW] Add a **"Bill Month"** field (DatePicker or custom Month/Year picker).
- Update the `_showExtractedDataDialog` to include the Bill Month.

### [Camera Scanner Screen]

#### [MODIFY] [camera_scanner_screen.dart](file:///C:/Users/Pc/Downloads/meterunit_flutter_app/meterunit/lib/screens/camera_scanner_screen.dart)
- **New Scanner Stages**: Add `searchingDate`, `searchingRefNo`, `searchingDetails` to `ScannerStage` for bill mode.
- **Sequential Detection**:
    - In `_startLiveStream`, only look for the Reference No once a valid Current Month Date is found.
    - Only return results once all required fields are detected or the user captures a photo.
- **Dynamic Viewfinder**:
    - Update `_OverlayPainter` to draw corners like in the screenshot.
    - Change colors based on detection:
        - Red: Searching for current element.
        - Green: Element found/verified.
- **On-Screen Messages**: Show "CHECKING BILL DATE...", "DETECTING REFERENCE NO...", etc.

### [Models & Services]

#### [MODIFY] [meter.dart](file:///C:/Users/Pc/Downloads/meterunit_flutter_app/meterunit/lib/models/meter.dart)
- Add `billMonth` (DateTime or String) to `MeterModel`.

#### [MODIFY] [ocr_service.dart](file:///C:/Users/Pc/Downloads/meterunit_flutter_app/meterunit/lib/services/ocr_service.dart)
- Ensure date detection is robust for FESCO bills.

## Verification Plan

### Manual Verification
- **UI Check**: Verify the tabbed interface in `AddMeterScreen`.
- **Scanner Flow**:
    - Point camera at a bill.
    - Observe the viewfinder is Red and shows "CHECKING DATE".
    - Once date is found (and it's current month), verify it moves to "DETECTING REFERENCE NO" and shows some visual success (Green corners?).
- **Manual Data**: Check if "Bill Month" is saved correctly in manual entry.
