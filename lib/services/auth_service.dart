import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AuthSignInResult {
  const AuthSignInResult({required this.user, required this.isVerified});
  final User? user;
  final bool isVerified;
}

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const _defaultServiceId = 'service_zue4ncs';
  static const _defaultTemplateId = 'template_hkznxbc';
  static const _defaultPublicKey = 'oLYVdT8DgvxIUdOjj';
  static const _otpLifetime = Duration(minutes: 30);
  static const _resendCooldown = Duration(seconds: 45);
  static const _maxAttempts = 10;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> signUp(
      {required String email, required String password}) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw StateError('Firebase did not return the newly created account.');
    }
    return user;
  }

  Future<void> saveProfile({
    required User user,
    required String email,
    String? displayName,
    String? phoneNumber,
  }) async {
    if (displayName != null && displayName.trim().isNotEmpty) {
      await user.updateDisplayName(displayName.trim());
    }
    await _firestore.collection('users').doc(user.uid).set({
      'email': email.trim(),
      'displayName': displayName?.trim() ?? '',
      'phoneNumber': phoneNumber?.trim() ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).timeout(const Duration(seconds: 15));
  }

  Future<AuthSignInResult> signIn(
      {required String email, required String password}) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return AuthSignInResult(
      user: credential.user,
      isVerified: await isOtpVerified(),
    );
  }

  Future<void> requestOtp({String? email, String? name}) async {
    final user = _auth.currentUser;
    final toEmail = (email ?? user?.email ?? '').trim();
    if (user == null || toEmail.isEmpty) {
      throw StateError('Please sign in before requesting a verification code.');
    }

    final serviceId = _envOrDefault('EMAILJS_SERVICE_ID', _defaultServiceId);
    final templateId = _envOrDefault('EMAILJS_TEMPLATE_ID', _defaultTemplateId);
    final publicKey = _envOrDefault('EMAILJS_PUBLIC_KEY', _defaultPublicKey);

    final userRef = _firestore.collection('users').doc(user.uid);
    final existing = await userRef.get();
    final data = existing.data();
    final lastSent = data?['otpSentAt'];

    // If within cooldown AND a valid unexpired code already exists,
    // return silently — the user already has a working code in their inbox.
    if (lastSent is Timestamp &&
        DateTime.now().difference(lastSent.toDate()) < _resendCooldown) {
      final expiresAt = data?['otpExpiresAt'];
      final hasValidCode = (data?['pendingOtpCode'] != null || data?['pendingOtpHash'] != null) &&
          (expiresAt is Timestamp && expiresAt.toDate().isAfter(DateTime.now()));
      if (hasValidCode) {
        // Existing code is still valid — no need to send a new one
        return;
      }
      throw StateError('Please wait before requesting another code.');
    }

    final code = (Random.secure().nextInt(900000) + 100000).toString();
    final toName = name?.trim().isNotEmpty == true
        ? name!.trim()
        : (user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : toEmail.split('@').first);

    final response = await http
        .post(
          Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'service_id': serviceId,
            'template_id': templateId,
            'user_id': publicKey,
            'template_params': {
              'to_email': toEmail,
              'recipient_email': toEmail,
              'email': toEmail,
              'user_email': toEmail,
              'reply_to': toEmail,
              'to_name': toName,
              'name': toName,
              'user_name': toName,
              'from_name': 'MeterPro',
              'otp_code': code,
              'verification_code': code,
              'code': code,
              'passcode': code,
              'subject': 'MeterPro verification code: $code',
              'message':
                  'Your MeterPro verification code is $code. It expires in 10 minutes.',
              'app_name': 'MeterPro',
            },
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final details = response.body.trim();
      throw StateError(
        'Email service error (${response.statusCode})${details.isEmpty ? '.' : ': $details'}',
      );
    }

    final otpHash = sha256.convert(utf8.encode(code)).toString();
    await userRef.set({
      'pendingOtpCode': code,
      'pendingOtpHash': otpHash,
      'otpExpiresAt': Timestamp.fromDate(DateTime.now().add(_otpLifetime)),
      'otpSentAt': FieldValue.serverTimestamp(),
      'otpAttempts': 0,
    }, SetOptions(merge: true));
  }

  Future<void> verifyOtp(String code) async {
    final normalized = code.replaceAll(RegExp(r'\D'), '').trim();
    if (normalized.length != 6) {
      throw StateError('Please enter a valid 6-digit code.');
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Please sign in before verifying your email.');
    }

    final userRef = _firestore.collection('users').doc(user.uid);
    final errorMsg = await _firestore.runTransaction<String?>((transaction) async {
      final snapshot = await transaction.get(userRef);
      final data = snapshot.data();
      if (data == null) {
        return 'No user record found. Please tap Resend Code.';
      }

      final expiresAt = data['otpExpiresAt'];
      final attempts = (data['otpAttempts'] as num?)?.toInt() ?? 0;
      final expectedHash = data['pendingOtpHash']?.toString();
      final expectedCode = data['pendingOtpCode']?.toString();

      if (expectedHash == null && expectedCode == null) {
        return 'No active verification code found. Please tap Resend Code.';
      }

      if (attempts >= _maxAttempts) {
        return 'Too many incorrect attempts. Please tap Resend Code for a new code.';
      }

      if (expiresAt is Timestamp && expiresAt.toDate().isBefore(DateTime.now())) {
        return 'Verification code has expired. Please tap Resend Code.';
      }

      final submittedHash = sha256.convert(utf8.encode(normalized)).toString();
      final isMatch = (expectedCode != null && expectedCode == normalized) ||
          (expectedHash != null && expectedHash == submittedHash);

      if (!isMatch) {
        transaction.update(userRef, {'otpAttempts': attempts + 1});
        return 'Incorrect verification code. Please check your email or tap Resend Code.';
      }

      transaction.update(userRef, {
        'isVerified': true,
        'emailOtpVerified': true,
        'verifiedAt': FieldValue.serverTimestamp(),
        'pendingOtpCode': FieldValue.delete(),
        'pendingOtpHash': FieldValue.delete(),
        'otpExpiresAt': FieldValue.delete(),
        'otpSentAt': FieldValue.delete(),
        'otpAttempts': FieldValue.delete(),
      });
      return null; // success
    });

    if (errorMsg != null) {
      throw StateError(errorMsg);
    }
  }

  Future<bool> isOtpVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 8));
      final data = doc.data();
      return data?['isVerified'] == true || data?['emailOtpVerified'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> updateProfileName(String name) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.updateDisplayName(name.trim());
    await _firestore
        .collection('users')
        .doc(user.uid)
        .update({'displayName': name.trim()});
  }

  Future<void> sendPasswordReset() async {
    final email = _auth.currentUser?.email;
    if (email != null) await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No signed-in user.');
    final userRef = _firestore.collection('users').doc(user.uid);
    final meters = await userRef.collection('meters').get();
    final batch = _firestore.batch();
    for (final meter in meters.docs) {
      batch.delete(meter.reference);
    }
    batch.delete(userRef);
    await batch.commit();
    await user.delete();
  }

  Future<void> signOut() => _auth.signOut();

  static String _envOrDefault(String key, String fallback) {
    final value = dotenv.env[key]?.trim();
    return value == null || value.isEmpty ? fallback : value;
  }

  static String messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Password is too weak (min. 8 characters).';
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }
}
