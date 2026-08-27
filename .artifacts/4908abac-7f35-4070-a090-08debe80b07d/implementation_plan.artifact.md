# Implementation Plan - Authentication & UI Overhaul

Update the MeterUnit app to match the provided designs exactly, fix authentication issues (OTP, login by email/phone), and implement a forgot password flow.

## User Review Required

> [!IMPORTANT]
> **Authentication Strategy**: To support login via both Email and Phone with the same password, we will store a mapping of phone numbers to email addresses in Firestore during sign-up.
> **Forgot Password**: Firebase Authentication typically uses a link sent via email for password resets. I will implement a flow that starts with OTP verification to match your request, but please note that final password updates usually require the user to be either signed in recently or use the Firebase-provided link. I will attempt to make the OTP flow as seamless as possible.

## Proposed Changes

### [Component] Authentication & User Management

#### [MODIFY] [auth_service.dart](file:///C:/Users/Pc/Downloads/meterunit_flutter_app/meterunit/lib/services/auth_service.dart)
- Update `signUp` to also save user metadata (phone number) in Firestore.
- Update `signIn` to handle both email and phone number.
- Add `resetPassword` functionality.

#### [MODIFY] [email_otp_service.dart](file:///C:/Users/Pc/Downloads/meterunit_flutter_app/meterunit/lib/services/email_otp_service.dart)
- Improve error handling and logging to diagnose why OTPs are not arriving.
- Verify configuration values.

### [Component] UI Overhaul (Screens)

#### [MODIFY] [login_screen.dart](file:///C:/Users/Pc/Downloads/meterunit_flutter_app/meterunit/lib/screens/login_screen.dart)
- Redesign to match the "Welcome back" screen in Image 01.
- Ensure the Email/Phone toggle works and handles input correctly.

#### [MODIFY] [signup_screen.dart](file:///C:/Users/Pc/Downloads/meterunit_flutter_app/meterunit/lib/screens/signup_screen.dart)
- Redesign to match the "Create Account" screen in Image 02.
- Add validation for phone number and password matching.

#### [MODIFY] [otp_verify_screen.dart](file:///C:/Users/Pc/Downloads/meterunit_flutter_app/meterunit/lib/screens/otp_verify_screen.dart)
- Redesign to match the "Verify Email OTP" screen in Image 03.

#### [NEW] [forgot_password_screen.dart](file:///C:/Users/Pc/Downloads/meterunit_flutter_app/meterunit/lib/screens/forgot_password_screen.dart)
- Create a new screen for requesting a password reset, following the design language.

#### [MODIFY] [dashboard_screen.dart](file:///C:/Users/Pc/Downloads/meterunit_flutter_app/meterunit/lib/screens/dashboard_screen.dart)
- Redesign the dashboard home to match Image 04.
- Update the "Total Consumption" and "Est. Bill" cards.

#### [MODIFY] [usage_screen.dart](file:///C:/Users/Pc/Downloads/meterunit_flutter_app/meterunit/lib/screens/usage_screen.dart)
- Redesign to match the "Usage Analytics" screen.

#### [MODIFY] [bills_screen.dart](file:///C:/Users/Pc/Downloads/meterunit_flutter_app/meterunit/lib/screens/bills_screen.dart)
- Redesign to match the "My Bills" screen.

#### [MODIFY] [profile_screen.dart](file:///C:/Users/Pc/Downloads/meterunit_flutter_app/meterunit/lib/screens/profile_screen.dart)
- Redesign to match the "Profile" screen.

#### [MODIFY] [meter_detail_screen.dart](file:///C:/Users/Pc/Downloads/meterunit_flutter_app/meterunit/lib/screens/meter_detail_screen.dart)
- Redesign to match Image 05.

#### [MODIFY] [add_meter_screen.dart](file:///C:/Users/Pc/Downloads/meterunit_flutter_app/meterunit/lib/screens/add_meter_screen.dart)
- Redesign to match Image 06.

### [Component] Theme & Assets

#### [MODIFY] [app_theme.dart](file:///C:/Users/Pc/Downloads/meterunit_flutter_app/meterunit/lib/theme/app_theme.dart)
- Update colors, gradients, and typography tokens to match the "DESIGN TOKENS" section in the image.

## Verification Plan

### Manual Verification
- **Sign Up**: Create an account with both email and phone. Verify data is saved in Firestore.
- **OTP**: Check if OTP is received on the provided email.
- **Login (Email)**: Log in using the email and password.
- **Login (Phone)**: Log in using the phone number and password.
- **Forgot Password**: Request reset, verify OTP, and reset password.
- **UI Consistency**: Compare every screen with the provided images.
