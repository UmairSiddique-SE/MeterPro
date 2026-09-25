import 'dart:convert';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AuthSignInResult {
  const AuthSignInResult({required this.user, required this.isVerified});

  final User? user;
  final bool isVerified;
}

/// Central authentication service for MeterPro.
///
/// Handles user registration, email OTP generation and delivery via EmailJS,
/// and Firestore profile verification state.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // In-memory OTP storage for immediate verification
  String? _pendingOtp;
  String? _pendingOtpEmail;
  DateTime? _otpExpiresAt;

  // Fallback EmailJS configuration if not provided in .env
  static const _defaultServiceId = 'service_zue4ncs';
  static const _defaultTemplateId = 'template_hkznxbc';
  static const _defaultPublicKey = 'oLYVdT8DgvxIUdOjj';
  static const _defaultPrivateKey = 'PsmaVOt6LDjn04tpIlAqW';

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> signUp({
    required String email,
    required String password,
  }) async {
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
      'isVerified': true,
      'emailOtpVerified': true,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).timeout(const Duration(seconds: 15));
  }

  Future<AuthSignInResult> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    return AuthSignInResult(
      user: user,
      isVerified: await isOtpVerified(),
    );
  }

  /// Generates a 6-digit OTP code and delivers it to the user's email via EmailJS.
  Future<void> requestOtp({String? email, String? name}) async {
    final toEmail = (email ?? _auth.currentUser?.email ?? '').trim();
    if (toEmail.isEmpty) {
      throw StateError('No recipient email address provided.');
    }

    final serviceId = dotenv.env['EMAILJS_SERVICE_ID']?.trim().isNotEmpty == true
        ? dotenv.env['EMAILJS_SERVICE_ID']!.trim()
        : _defaultServiceId;
    final templateId = dotenv.env['EMAILJS_TEMPLATE_ID']?.trim().isNotEmpty == true
        ? dotenv.env['EMAILJS_TEMPLATE_ID']!.trim()
        : _defaultTemplateId;
    final publicKey = dotenv.env['EMAILJS_PUBLIC_KEY']?.trim().isNotEmpty == true
        ? dotenv.env['EMAILJS_PUBLIC_KEY']!.trim()
        : _defaultPublicKey;
    final privateKey = dotenv.env['EMAILJS_PRIVATE_KEY']?.trim().isNotEmpty == true
        ? dotenv.env['EMAILJS_PRIVATE_KEY']!.trim()
        : _defaultPrivateKey;

    // Generate secure 6-digit code
    final code = (Random.secure().nextInt(900000) + 100000).toString();
    final toName = (name != null && name.trim().isNotEmpty)
        ? name.trim()
        : toEmail.split('@').first;

    // Send via EmailJS API
    final response = await http
        .post(
          Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
          headers: {
            'Content-Type': 'application/json',
            'origin': 'http://localhost',
          },
          body: jsonEncode({
            'service_id': serviceId,
            'template_id': templateId,
            'user_id': publicKey,
            'accessToken': privateKey,
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
              'message': 'Your MeterPro verification code is $code. It expires in 10 minutes.',
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

    _pendingOtp = code;
    _pendingOtpEmail = toEmail;
    _otpExpiresAt = DateTime.now().add(const Duration(minutes: 10));

    // Also persist OTP in Firestore for cross-session/backup verification if user is logged in
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).set({
          'pendingOtp': code,
          'otpExpiresAt': _otpExpiresAt?.toIso8601String(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  /// Verifies the entered 6-digit code against pending OTP and marks the account as verified.
  Future<void> verifyOtp(String code) async {
    final normalized = code.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(normalized)) {
      throw StateError('Please enter a valid 6-digit code.');
    }

    final user = _auth.currentUser;
    bool isValid = false;

    // 1. Check in-memory OTP
    if (_pendingOtp != null && _otpExpiresAt != null) {
      if (DateTime.now().isAfter(_otpExpiresAt!)) {
        _pendingOtp = null;
        throw StateError('Verification code has expired. Please request a new one.');
      }
      if (_pendingOtp == normalized) {
        isValid = true;
      }
    }

    // 2. Check Firestore backup OTP if in-memory did not match or was lost
    if (!isValid && user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data();
          final storedOtp = data?['pendingOtp']?.toString();
          final expiryStr = data?['otpExpiresAt']?.toString();
          if (storedOtp == normalized && expiryStr != null) {
            final expiry = DateTime.tryParse(expiryStr);
            if (expiry != null && DateTime.now().isBefore(expiry)) {
              isValid = true;
            }
          }
        }
      } catch (_) {}
    }

    if (!isValid) {
      throw StateError('Invalid verification code. Please check your email and try again.');
    }

    // Clear OTP and mark verified
    _pendingOtp = null;
    _pendingOtpEmail = null;
    _otpExpiresAt = null;

    if (user != null) {
      await _firestore.collection('users').doc(user.uid).set({
        'isVerified': true,
        'emailOtpVerified': true,
        'verifiedAt': FieldValue.serverTimestamp(),
        'pendingOtp': FieldValue.delete(),
        'otpExpiresAt': FieldValue.delete(),
      }, SetOptions(merge: true));
    }
  }

  /// Checks if the current user has completed email verification.
  Future<bool> isOtpVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    if (user.emailVerified) return true;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 8));

      if (!doc.exists) return false;

      final data = doc.data();
      if (data == null) return false;

      // If marked verified or user profile already established
      return data['isVerified'] == true ||
          data['emailOtpVerified'] == true ||
          data.containsKey('createdAt');
    } catch (_) {
      // In case of offline/network glitch, check user session
      return user.email != null && user.email!.isNotEmpty;
    }
  }

  Future<void> updateProfileName(String name) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.updateDisplayName(name.trim());
    await _firestore.collection('users').doc(user.uid).update({
      'displayName': name.trim(),
    });
  }

  Future<void> sendPasswordReset() async {
    final email = _auth.currentUser?.email;
    if (email == null) return;
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No signed-in user.');

    final userRef = _firestore.collection('users').doc(user.uid);
    final meterSnapshot = await userRef.collection('meters').get();
    final batch = _firestore.batch();
    for (final meter in meterSnapshot.docs) {
      batch.delete(meter.reference);
    }
    batch.delete(userRef);
    await batch.commit();
    await user.delete();
  }

  Future<void> signOut() => _auth.signOut();

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
