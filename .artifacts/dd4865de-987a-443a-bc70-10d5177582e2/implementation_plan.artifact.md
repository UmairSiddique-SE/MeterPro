# Implementation Plan - Notification Reminders & Time Picker

Implement a professional bottom sheet widget for notification settings where users can toggle notifications ON/OFF and select a custom reminder time for "Check meter reading" reminders.

## User Review Required

> [!IMPORTANT]
> - **Notification Settings Bottom Sheet**: Clicking the notification bell on the dashboard will open a professional bottom sheet UI.
> - **Features**:
>   - Toggle Notification ON/OFF switch.
>   - Time Picker to select reminder time.
>   - Persistence and scheduling via `ReminderService`.

## Open Questions

None. The user requirements are clear ("notification par click kary to option hy notifictaion of and notifiction tume phir os time par remonder ajay chaek meter reading sahi professional wala semnn bana dena").

## Proposed Changes

### Notification Settings Sheet & Dashboard Integration

#### [NEW] [notification_settings_sheet.dart](file:///D:/Project/meterpro/lib/widgets/notification_settings_sheet.dart)
- Create a professional modal bottom sheet component (`NotificationSettingsSheet`) using `ReminderService` to load and save settings (enable/disable toggle and time picker).

#### [MODIFY] [dashboard_screen.dart](file:///D:/Project/meterpro/lib/screens/dashboard_screen.dart)
- Update the notification button tap handler to display `NotificationSettingsSheet` instead of the placeholder dialog.

## Verification Plan

### Automated Tests
- Run `flutter analyze` to ensure zero compilation errors or warnings.

### Manual Verification
- Tap notification bell on dashboard.
- Verify notification toggle works, time picker works, and saving correctly schedules the notification.
