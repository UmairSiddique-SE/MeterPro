# MeterPro

Flutter app for electricity meter and bill management.

Authentication uses Firebase Authentication email/password accounts with a custom six-digit email OTP. Firebase's email-verification links are not used. OTPs are generated, hashed, rate-limited, and checked by Firebase Cloud Functions; verified users receive the `emailOtpVerified` custom claim.

## Public Android release

The app includes an in-app update check using the public Firestore document `app_config/android`.

1. Create a private release key and copy `android/key.properties.example` to `android/key.properties`.
2. Fill in the keystore values, then build the signed APK:

   ```powershell
   flutter clean
   flutter pub get
   flutter build apk --release
   Rename-Item build\app\outputs\flutter-apk\app-release.apk MeterPro.apk -Force
   Copy-Item build\app\outputs\flutter-apk\MeterPro.apk public\MeterPro.apk
   ```

3. Deploy the download page and Firestore rules:

   ```powershell
   firebase deploy --only hosting,firestore:rules
   ```

4. In Firestore, create `app_config/android` with `version`, `buildNumber`, `apkUrl`, `releaseNotes`, and `forceUpdate` fields. Increase `buildNumber` for every release. The APK URL should be `https://metrowatt-2614f.web.app/meterpro.apk`.

Never commit `android/key.properties` or the release keystore. Keep a secure backup of both the keystore and its passwords; all future APK updates must use the same signing key.

## Deploy the OTP mailer

1. The Firebase project is already set to `metrowatt-2614f` in `.firebaserc`. In Firebase Console, enable **Authentication \u2192 Sign-in method \u2192 Email/Password** and create Firestore if it is not already enabled.
2. From `functions`, run `npm install`.
3. EmailJS has a service called **MeterPro** with service ID `service_zue4ncs`. Create an EmailJS template that uses `{{to_email}}`, `{{to_name}}`, and `{{otp_code}}`; configure its sender as a verified address/domain in EmailJS for deliverability. Set the EmailJS values as Firebase secrets:

   ```powershell
   firebase functions:secrets:set EMAILJS_SERVICE_ID # enter: service_zue4ncs
   firebase functions:secrets:set EMAILJS_TEMPLATE_ID
   firebase functions:secrets:set EMAILJS_PUBLIC_KEY
   firebase functions:secrets:set EMAILJS_PRIVATE_KEY
   ```

4. Deploy both the server functions and rules:

   ```powershell
   firebase deploy --only functions,firestore:rules
   ```

The OTP is valid for 5 minutes, replaces any prior code, can be resent once per minute, and is invalidated after five failed attempts. Do not put EmailJS private keys in the Flutter app.

After deployment, create an account in the app. A valid six-digit code now opens the dashboard; until verification, Firestore meter data remains protected.
