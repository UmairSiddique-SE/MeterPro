# MeterPro — Meter Unit Tracker & Electricity Bill App

**MeterPro by Umair** is a meter unit tracker and electricity bill management app for tracking electricity meter readings, units, estimated bills, and meter history.

**Search terms:** meter unit tracker · meter unit · meter app · meter tracker · electricity unit tracker · meter reading app · MeterPro by Umair · meter app by Umair

**Official website:** https://meterpro-official.web.app/


MeterPro is a Flutter application for electricity meter and bill management, with Firebase-backed authentication, OTP verification, cloud functions, and protected meter data.

## Highlights

- Firebase Authentication with email/password
- Custom six-digit email OTP verification
- OTP generation, hashing, rate limiting, expiry, and failed-attempt protection
- Firebase Cloud Functions for server-side OTP handling
- Firestore-backed meter data
- Public Android release/update workflow
- Google ML Kit and camera capabilities
- Firebase Hosting and Firestore security rules

## Technology

- Dart
- Flutter
- Firebase Authentication
- Cloud Firestore
- Firebase Cloud Functions
- Google ML Kit
- Camera
- Firebase Hosting

## Android release

For signed Android releases:

1. Create a private release keystore.
2. Copy `android/key.properties.example` to `android/key.properties`.
3. Configure the local signing values.
4. Build the release APK:

```powershell
flutter clean
flutter pub get
flutter build apk --release
```

Never commit `android/key.properties`, private signing keys, or passwords.

## OTP mailer

The OTP mailer is implemented through Firebase Cloud Functions and an external email delivery service. Provider credentials and private keys must be stored as deployment secrets and must never be placed in the Flutter client.

The OTP flow is designed with a five-minute validity period, resend throttling, replacement of previous codes, and failed-attempt protection.

## Development

Install Flutter dependencies with:

```bash
flutter pub get
```

Firebase project configuration and deployment secrets are environment/deployment specific and should not be committed to the repository.

## Maintainer

**Umair Siddique**

GitHub: https://github.com/UmairSiddique-SE
