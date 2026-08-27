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

/// Wraps Firebase Authentication (email/password) for MeterUnit.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _pendingOtp;
  DateTime? _otpExpiresAt;

  static const _emailJsServiceId = 'service_zue4ncs';
  static const _emailJsTemplateId = 'template_hkznxbc';
  static const _emailJsPublicKey = 'oLYVdT8DgvxIUdOjj';
  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Creates a new Firebase account. Throws [FirebaseAuthException] on failure
  /// (e.g. 'email-already-in-use', 'weak-password').
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
    if (displayName != null && displayName.isNotEmpty) {
      await user.updateDisplayName(displayName);
    }
    await _firestore.collection('users').doc(user.uid).set({
      'email': email.trim(),
      'displayName': displayName?.trim() ?? '',
      'phoneNumber': phoneNumber?.trim() ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    }).timeout(const Duration(seconds: 15));
  }

  /// Signs in an existing user. Throws [FirebaseAuthException] on failure
  /// (e.g. 'user-not-found', 'wrong-password', 'invalid-credential').
  Future<AuthSignInResult> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    return AuthSignInResult(user: user, isVerified: await isOtpVerified());
  }

  Future<void> requestOtp({String? email, String? name}) async {
    final toEmail = (email ?? _auth.currentUser?.email ?? '').trim();
    if (toEmail.isEmpty) throw StateError('No email address found.');
    final privateKey = dotenv.env['EMAILJS_PRIVATE_KEY']?.trim() ?? '';
    if (privateKey.isEmpty) {
      throw StateError(
        'EmailJS private key is missing from .env.',
      );
    }

    final code = (Random.secure().nextInt(900000) + 100000).toString();
    final response = await http
        .post(
          Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'service_id': _emailJsServiceId,
            'template_id': _emailJsTemplateId,
            'user_id': _emailJsPublicKey,
            'accessToken': privateKey,
            'template_params': {
              'to_email': toEmail,
              'recipient_email': toEmail,
              'email': toEmail,
              'to_name': name?.trim() ?? toEmail.split('@').first,
              'name': name?.trim() ?? toEmail.split('@').first,
              'otp_code': code,
              'app_name': 'MeterPro',
            },
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final details = response.body.trim();
      throw StateError(
        'EmailJS failed (${response.statusCode})${details.isEmpty ? '.' : ': $details'}',
      );
    }
    _pendingOtp = code;
    _otpExpiresAt = DateTime.now().add(const Duration(minutes: 5));
  }

  Future<void> verifyOtp(String code) async {
    if (_pendingOtp == null || _otpExpiresAt == null) {
      throw StateError('Request a new code first.');
    }
    if (DateTime.now().isAfter(_otpExpiresAt!)) {
      _pendingOtp = null;
      throw StateError('expired');
    }
    if (code != _pendingOtp) throw StateError('invalid');
    _pendingOtp = null;
  }

  Future<bool> isOtpVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final profile = await _firestore
        .collection('users')
        .doc(user.uid)
        .get()
        .timeout(const Duration(seconds: 15));
    return profile.exists;
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

  /// Human-readable message for a FirebaseAuthException.
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
