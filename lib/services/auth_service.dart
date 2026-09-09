import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AuthSignInResult {
  const AuthSignInResult({required this.user, required this.isVerified});

  final User? user;
  final bool isVerified;
}

/// Central authentication service for MeterPro.
///
/// Firebase Authentication handles the account/password session. Email OTPs
/// are handled by Firebase Cloud Functions so the EmailJS private key and OTP
/// generation never ship inside the Flutter client.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

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
      'createdAt': FieldValue.serverTimestamp(),
    }).timeout(const Duration(seconds: 15));
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

  Future<void> requestOtp({String? email, String? name}) async {
    if (_auth.currentUser == null) {
      throw FirebaseFunctionsException(
        code: 'unauthenticated',
        message: 'Sign in before requesting a verification code.',
      );
    }

    await _functions.httpsCallable('requestEmailOtp').call(<String, dynamic>{
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
    });
  }

  Future<void> verifyOtp(String code) async {
    final normalized = code.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(normalized)) {
      throw FirebaseFunctionsException(
        code: 'invalid-argument',
        message: 'Enter a six-digit code.',
      );
    }

    await _functions.httpsCallable('verifyEmailOtp').call(<String, dynamic>{
      'code': normalized,
    });

    // Cloud Functions sets the emailOtpVerified custom claim. Refresh the
    // local ID token so the claim is immediately available to the app.
    await _auth.currentUser?.getIdToken(true);
  }

  Future<bool> isOtpVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final token = await user.getIdTokenResult(true);
      return token.claims?['emailOtpVerified'] == true;
    } catch (_) {
      return false;
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
