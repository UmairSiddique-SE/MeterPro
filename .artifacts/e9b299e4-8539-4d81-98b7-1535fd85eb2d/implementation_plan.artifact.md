# Implementation Plan - Integrated Reading Input & Scanner with Gallery

This plan addresses the request to show a reading input box directly in the "Add Meter Reading" view, provide a scan option below it, and add a gallery upload feature to the camera scanner.

## Proposed Changes

### [Screens]

#### [MODIFY] [meter_detail_screen.dart](file:///C:/Users/Pc/Downloads/meterunit_flutter_app/meterunit/lib/screens/meter_detail_screen.dart)
- Redesign `_showAddReadingOptions` (the bottom sheet) to:
    - Include a prominent **Reading Input Box** (kWh).
    - Add a "Scan from Camera" button below the input.
    - Add a "Save Reading" button at the bottom.
- This allows users to either type immediately or jump to the camera for assistance.

#### [MODIFY] [camera_scanner_screen.dart](file:///C:/Users/Pc/Downloads/meterunit_flutter_app/meterunit/lib/screens/camera_scanner_screen.dart)
- Re-import `image_picker`.
- Re-implement `_pickFromGallery()` method to allow scanning from existing photos.
- Add a **Gallery Button** to the camera UI (usually near the capture button).
- Ensure that once a reading is detected (either via live stream, capture, or gallery), it is returned and populates the input box in the previous screen.

### [UI/UX Refinements]
- Use a **Stateful Builder** inside the bottom sheet in `MeterDetailScreen` so the text field and buttons interact correctly.
- Advise users that they can now upload a photo if the live camera is having trouble with reflections.

## Verification Plan

### Manual Verification
- **Direct Entry**: Tap "Add Meter Reading", type a value, and press "Save".
- **Scan Flow**: Tap "Add Meter Reading", tap "Scan Meter", verify camera opens.
- **Gallery Test**: In the camera screen, tap the gallery icon, pick the meter photo provided by the user, and verify digits are extracted.
