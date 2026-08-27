# Implementation Plan - Bills Screen Redesign & Payment Flow

Redesign the "My Bills" screen to match the professional layout provided in the reference images, including a direct link to the PITC online bill and a new payment method selection flow.

## User Review Required

> [!IMPORTANT]
> - **Online Bill Link**: The "Online Bill" button will automatically open the browser and navigate to the official PITC website with the meter's reference number already filled in.
> - **Pay Now Flow**: The "Pay Now" button will open a modern bottom sheet displaying the amount and various payment options (JazzCash, EasyPaisa, etc.).
> - **Estimated Amounts**: All amounts shown on this screen will be based on the consumption calculations performed in the app.

## Proposed Changes

### [Bills Screen]

#### [MODIFY] [bills_screen.dart](file:///C:/Users/Pc/Downloads/meterunit_flutter_app/meterunit/lib/screens/bills_screen.dart)
- **Top Summary Card**:
    - Update to show "TOTAL AMOUNT DUE" in a large font.
    - Add a "Pay All Bills" action button inside the card.
    - Include a dynamic subtitle showing the due date and the number of meters.
- **Individual Bills List**:
    - Overhaul the card design to show Name, Sr. No., and Status Badge at the top.
    - Display "UNITS" and "AMOUNT DUE" side-by-side in the middle section.
    - Add two action buttons at the bottom:
        1. **Online Bill**: Uses `url_launcher` to open `https://bill.pitc.com.pk/fescobill/general?refno={referenceNo}`.
        2. **Pay Now**: Triggers a bottom sheet.
- **Payment Bottom Sheet**:
    - Create a private method `_showPaymentBottomSheet` that displays:
        - The bill amount.
        - List tiles for JazzCash, EasyPaisa, Card, and Bank Transfer with appropriate icons.

### [Dependencies]

#### [VERIFY] [pubspec.yaml](file:///C:/Users/Pc/Downloads/meterunit_flutter_app/meterunit/pubspec.yaml)
- Ensure `url_launcher` is present (already confirmed in previous steps).

## Verification Plan

### Manual Verification
1.  **Summary Card**: Verify the total amount is the sum of all individual meter bills.
2.  **Online Bill**: Click the button for a meter. Verify the browser opens with the correct PITC URL and reference number.
3.  **Pay Now**: Click the button. Verify the bottom sheet opens with the correct meter name, amount, and list of payment methods.
4.  **UI Consistency**: Ensure the fonts, colors, and layout match the provided screenshots.
