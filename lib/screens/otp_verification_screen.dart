import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.email,
    this.name,
    this.phoneNumber,
    // sendInitialCode: true so code auto-sends on screen load
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
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    if (widget.sendInitialCode) {
      // Only for brand-new signup — send first code automatically
      WidgetsBinding.instance.addPostFrameCallback((_) => _sendCode(isInitial: true));
    }
    // For all other cases: cooldown = 0, "Send Code" button is immediately visible
    // No auto-send, no auto-verify — user is in full control
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    for (final c in _codeControllers) {
      c.dispose();
    }
    for (final f in _codeFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startCooldown([int seconds = 45]) {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _cooldownSeconds = 0);
      } else {
        if (mounted) setState(() => _cooldownSeconds--);
      }
    });
  }

  // ── VERIFY: only called when user taps "Verify & Continue" button ─────────
  Future<void> _verify() async {
    final code = _codeControllers.map((c) => c.text.trim()).join();
    if (code.length != 6) {
      _show('Please enter all 6 digits of your verification code.');
      return;
    }

    setState(() => _loading = true);
    try {
      await AuthService.instance.verifyOtp(code);

      // Save profile — uses merge:true so old data is NEVER deleted
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
      // Pop back to _AuthGate which will detect isVerified=true and open Dashboard
      Navigator.of(context).popUntil((route) => route.isFirst);
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

  // ── SEND CODE: only called when user taps "Send Code" / "Resend Code" ─────
  Future<void> _sendCode({bool isInitial = false}) async {
    if (!mounted) return;
    if (!isInitial && _cooldownSeconds > 0) {
      _show('Please wait $_cooldownSeconds seconds before requesting a new code.');
      return;
    }
    setState(() => _loading = true);
    try {
      await AuthService.instance.requestOtp(
        email: widget.email,
        name: widget.name,
      );
      if (!mounted) return;
      _clearCode();
      _startCooldown(45);
      _show(isInitial
          ? 'Verification code sent to ${widget.email}. Check your inbox.'
          : 'New verification code sent to ${widget.email}. Check your inbox.');
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
          duration: const Duration(seconds: 5),
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

  // Digit input — NO auto-verify, user must tap the button
  void _onDigitChanged(int index, String value) {
    if (_codeInvalid) setState(() => _codeInvalid = false);

    // Handle paste (6 digits at once)
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      if (digits.isNotEmpty) {
        for (int i = 0; i < 6; i++) {
          _codeControllers[i].text = i < digits.length ? digits[i] : '';
        }
        final target = (digits.length >= 6) ? 5 : digits.length;
        _codeFocusNodes[target].requestFocus();
        // NO auto-verify here — user taps the button themselves
        return;
      }
    }

    // Move focus forward, but never auto-verify
    if (value.isNotEmpty && index < 5) {
      _codeFocusNodes[index + 1].requestFocus();
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
    if (lower.contains('socket') || lower.contains('network') ||
        lower.contains('timeout') || lower.contains('client')) {
      return 'No internet connection. Please check your network and try again.';
    }
    if (lower.contains('expired')) {
      return 'Code has expired. Please tap "Send Code" to get a new one.';
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
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: Colors.green, size: 48),
              ),
              const SizedBox(height: 20),
              const Text(
                'Verified!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.lightTextPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Your email has been verified successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Continue to Dashboard',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: const Text('Email Verification',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor:
            isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 8),

              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.22),
                    width: 2,
                  ),
                ),
                child: const Icon(Icons.mark_email_read_outlined,
                    size: 40, color: AppColors.primary),
              ),
              const SizedBox(height: 24),

              Text(
                'Email Verification',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(text: 'A 6-digit code has been sent to\n'),
                    TextSpan(
                      text: widget.email,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── 6 OTP Boxes ──────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 46,
                    height: 58,
                    child: KeyboardListener(
                      focusNode: FocusNode(),
                      onKeyEvent: (event) {
                        if (event is KeyDownEvent &&
                            event.logicalKey ==
                                LogicalKeyboardKey.backspace &&
                            _codeControllers[index].text.isEmpty &&
                            index > 0) {
                          _codeFocusNodes[index - 1].requestFocus();
                        }
                      },
                      child: TextField(
                        controller: _codeControllers[index],
                        focusNode: _codeFocusNodes[index],
                        autofocus: false, // no autofocus, no autofill triggers
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : AppColors.lightTextPrimary,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: isDark
                              ? AppColors.darkSurface
                              : Colors.white,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: _codeInvalid
                                  ? Colors.red
                                  : (isDark
                                      ? AppColors.darkBorder
                                      : AppColors.lightBorder),
                              width: 1.2,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: _codeInvalid
                                  ? Colors.red
                                  : AppColors.primary,
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
              const SizedBox(height: 28),

              // ── Buttons ───────────────────────────────────────────────────
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(),
                )
              else ...[
                // VERIFY button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _verify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                    child: const Text(
                      'Verify & Continue',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // SEND CODE / RESEND CODE button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _cooldownSeconds > 0 ? null : () => _sendCode(),
                    icon: Icon(
                      _cooldownSeconds > 0
                          ? Icons.timer_outlined
                          : Icons.send_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _cooldownSeconds > 0
                          ? 'Resend Code in ${_cooldownSeconds}s'
                          : 'Resend Code',
                    ),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      side: BorderSide(
                        color: _cooldownSeconds > 0
                            ? (isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder)
                            : AppColors.primary,
                        width: 1.5,
                      ),
                      foregroundColor: _cooldownSeconds > 0
                          ? (isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted)
                          : AppColors.primary,
                      textStyle: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Open Gmail button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _openGmail,
                    icon: const Icon(Icons.mail_outline_rounded, size: 18),
                    label: const Text('Open Gmail Inbox'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                      ),
                      foregroundColor: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                      textStyle: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Tip card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.amber.withValues(alpha: 0.08)
                      : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 20, color: Colors.amber),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Check your email inbox (or Spam folder) for the 6-digit code. Tap "Resend Code" if you didn\'t receive it.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.amber.shade200
                              : const Color(0xFF92400E),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
