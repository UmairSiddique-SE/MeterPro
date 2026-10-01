import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.email,
    this.name,
    this.phoneNumber,
    this.sendInitialCode = true,
  });

  final String email;
  final String? name;
  final String? phoneNumber;
  final bool sendInitialCode;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _codeControllers = List.generate(6, (_) => TextEditingController());
  final _codeFocusNodes = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  bool _codeInvalid = false;

  @override
  void initState() {
    super.initState();
    if (widget.sendInitialCode) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _sendCode(isInitial: true));
    }
  }

  @override
  void dispose() {
    for (final c in _codeControllers) {
      c.dispose();
    }
    for (final f in _codeFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  // ── BACK TO LOGIN & SIGN OUT ───────────────────────────────────────────────
  Future<void> _handleBack() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.arrow_back_rounded, color: AppColors.primary),
            SizedBox(width: 10),
            Text(
              'Back to Login?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.lightTextPrimary,
              ),
            ),
          ],
        ),
        content: const Text(
          'Do you want to go back? You will be signed out so you can sign in with another email or edit your details.',
          style: TextStyle(fontSize: 14, color: AppColors.lightTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.lightTextSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Back to Login'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      try {
        await AuthService.instance.signOut();
      } catch (_) {}
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  // ── AUTO-VERIFY & VERIFY ──────────────────────────────────────────────────
  Future<void> _verify() async {
    if (_loading) return;
    final code = _codeControllers.map((c) => c.text.trim()).join();
    if (code.length != 6) {
      _show('Please enter all 6 digits of your verification code.');
      return;
    }

    setState(() => _loading = true);
    try {
      await AuthService.instance.verifyOtp(code);

      // Save profile
      final user = AuthService.instance.currentUser;
      if (user != null) {
        await AuthService.instance.saveProfile(
          user: user,
          email: widget.email,
          displayName: widget.name,
          phoneNumber: widget.phoneNumber,
        );
      }

      if (!mounted) return;
      await _showSuccessDialog();
      if (!mounted) return;
      // Navigate directly to Dashboard
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (error) {
      _clearCode(markInvalid: true);
      _show(AuthService.messageFor(error));
    } catch (error) {
      _clearCode(markInvalid: true);
      _show(_messageFor(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── SEND / RESEND CODE (NO COOLDOWN WAITING TIME) ──────────────────────────
  Future<void> _sendCode({bool isInitial = false}) async {
    if (!mounted || _loading) return;
    setState(() => _loading = true);
    try {
      await AuthService.instance.requestOtp(
        email: widget.email,
        name: widget.name,
      );
      if (!mounted) return;
      _clearCode();
      _show(isInitial
          ? 'Verification code sent to ${widget.email}. Check your inbox.'
          : 'New verification code sent! Check your inbox.');
    } catch (error) {
      if (mounted) _show(_messageFor(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── GMAIL ─────────────────────────────────────────────────────────────────
  Future<void> _openGmail() async {
    final gmailApp = Uri.parse('googlegmail://');
    final gmailWeb = Uri.parse('https://mail.google.com/mail/u/0/#inbox');
    try {
      if (await canLaunchUrl(gmailApp)) {
        await launchUrl(gmailApp, mode: LaunchMode.externalApplication);
        return;
      }
      await launchUrl(gmailWeb, mode: LaunchMode.externalApplication);
    } catch (_) {
      _show('Could not open Gmail. Please open your mail app manually.');
    }
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────
  void _show(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _clearCode({bool markInvalid = false}) {
    for (final c in _codeControllers) {
      c.clear();
    }
    if (mounted) {
      setState(() => _codeInvalid = markInvalid);
      if (_codeFocusNodes.isNotEmpty) _codeFocusNodes.first.requestFocus();
    }
  }

  // ── DIGIT CHANGED & AUTO-VERIFY ───────────────────────────────────────────
  void _onDigitChanged(int index, String value) {
    if (_codeInvalid) setState(() => _codeInvalid = false);

    // Handle paste of 6 digits
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      if (digits.isNotEmpty) {
        for (int i = 0; i < 6; i++) {
          _codeControllers[i].text = i < digits.length ? digits[i] : '';
        }
        final target = (digits.length >= 6) ? 5 : digits.length;
        _codeFocusNodes[target].requestFocus();

        // Auto-verify if 6 digits pasted
        if (digits.length >= 6) {
          _verify();
        }
        return;
      }
    }

    // Move focus forward
    if (value.isNotEmpty && index < 5) {
      _codeFocusNodes[index + 1].requestFocus();
    }

    // Auto-verify when 6th digit is entered
    final currentCode = _codeControllers.map((c) => c.text.trim()).join();
    if (currentCode.length == 6) {
      _verify();
    }
  }

  String _messageFor(Object error) {
    if (error is FirebaseException) {
      return error.message ?? error.toString();
    }
    if (error is StateError) {
      return error.message;
    }
    final msg = error.toString();
    final lower = msg.toLowerCase();
    if (lower.contains('socket') ||
        lower.contains('network') ||
        lower.contains('timeout') ||
        lower.contains('client')) {
      return 'No internet connection. Please check your network and try again.';
    }
    if (lower.contains('expired')) {
      return 'Code has expired. Tap "Resend Code" to get a new one.';
    }
    if (lower.contains('invalid') || lower.contains('wrong') || lower.contains('incorrect')) {
      return 'Invalid code. Please check your email and try again.';
    }
    final cleaned = msg.replaceAll(RegExp(r'^Exception:\s*'), '').trim();
    return cleaned.isNotEmpty ? cleaned : 'Something went wrong. Please try again.';
  }

  Future<void> _showSuccessDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3), width: 2),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green,
                  size: 52,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Verified Successfully!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.lightTextPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Your email has been verified. You can now access your dashboard.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.lightTextSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const DashboardScreen()),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Continue to Dashboard',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.lightBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.lightBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: AppColors.lightTextPrimary,
              ),
            ),
            tooltip: 'Back to Login',
            onPressed: _handleBack,
          ),
          title: const Text(
            'Email Verification',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: AppColors.lightTextPrimary,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                const SizedBox(height: 12),

                // Vibrant Top Badge Icon
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.mark_email_read_rounded,
                    size: 44,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'Verify Your Email',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.lightTextPrimary,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),

                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(
                      color: AppColors.lightTextSecondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                    children: [
                      const TextSpan(text: 'We sent a 6-digit verification code to\n'),
                      TextSpan(
                        text: widget.email,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // ── 6 OTP Input Boxes ─────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _codeInvalid ? Colors.red.shade300 : AppColors.lightBorder,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(6, (index) {
                          return SizedBox(
                            width: 44,
                            height: 56,
                            child: KeyboardListener(
                              focusNode: FocusNode(),
                              onKeyEvent: (event) {
                                if (event is KeyDownEvent &&
                                    event.logicalKey == LogicalKeyboardKey.backspace &&
                                    _codeControllers[index].text.isEmpty &&
                                    index > 0) {
                                  _codeFocusNodes[index - 1].requestFocus();
                                }
                              },
                              child: TextField(
                                controller: _codeControllers[index],
                                focusNode: _codeFocusNodes[index],
                                autofocus: index == 0,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                maxLength: 1,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.lightTextPrimary,
                                ),
                                decoration: InputDecoration(
                                  counterText: '',
                                  filled: true,
                                  fillColor: AppColors.lightSurface2,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: _codeInvalid
                                          ? Colors.red
                                          : AppColors.lightBorder,
                                      width: 1.2,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: AppColors.primary,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                onChanged: (value) => _onDigitChanged(index, value),
                              ),
                            ),
                          );
                        }),
                      ),
                      if (_codeInvalid) ...[
                        const SizedBox(height: 12),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline_rounded, color: Colors.red, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Incorrect code. Please try again.',
                              style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ── Actions / Buttons ──────────────────────────────────────────
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text(
                          'Verifying code...',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  // Verify Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _verify,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Verify & Continue',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Resend Code Button (Instant, No timer cooldown)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () => _sendCode(),
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Resend Code'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                        foregroundColor: AppColors.primary,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.04),
                        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Open Gmail Inbox Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _openGmail,
                      icon: const Icon(Icons.mail_outline_rounded, size: 18),
                      label: const Text('Open Gmail Inbox'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: const BorderSide(color: AppColors.lightBorder),
                        foregroundColor: AppColors.lightTextSecondary,
                        backgroundColor: Colors.white,
                        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Helpful Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 20, color: Color(0xFFD97706)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Check your Inbox or Spam folder for the 6-digit code. Tap "Resend Code" anytime if you didn\'t receive it.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF92400E),
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Change Email / Back to Login
                TextButton.icon(
                  onPressed: _handleBack,
                  icon: const Icon(Icons.arrow_back_rounded, size: 17, color: AppColors.primary),
                  label: const Text(
                    'Wrong email? Back to Login',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
