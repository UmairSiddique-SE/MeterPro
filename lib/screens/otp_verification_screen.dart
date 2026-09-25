import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.email,
    this.name,
    this.phoneNumber,
    this.sendInitialCode = false,
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
      WidgetsBinding.instance.addPostFrameCallback((_) => _sendCode(isInitial: true));
    } else {
      _startCooldown(60);
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    for (final controller in _codeControllers) {
      controller.dispose();
    }
    for (final focusNode in _codeFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _startCooldown([int seconds = 60]) {
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

  Future<void> _verify() async {
    final code = _codeControllers.map((controller) => controller.text.trim()).join();
    if (code.length != 6) {
      _show('Please enter the complete 6-digit code.');
      return;
    }

    setState(() => _loading = true);
    try {
      await AuthService.instance.verifyOtp(code);

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
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
        (_) => false,
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

  Future<void> _sendCode({bool isInitial = false}) async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      await AuthService.instance.requestOtp(
        email: widget.email,
        name: widget.name,
      );
      if (!mounted) return;
      _clearCode();
      _startCooldown(60);
      _show(isInitial
          ? 'Verification code sent to ${widget.email}'
          : 'New code sent to ${widget.email}');
    } catch (error) {
      _show(_messageFor(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openGmailInbox() async {
    final gmailApp = Uri.parse('googlegmail://');
    final gmailWeb = Uri.parse('https://mail.google.com/mail/u/0/#inbox');
    try {
      if (await canLaunchUrl(gmailApp)) {
        await launchUrl(gmailApp, mode: LaunchMode.externalApplication);
        return;
      }
      await launchUrl(gmailWeb, mode: LaunchMode.externalApplication);
    } catch (_) {
      _show('Could not open Gmail. Please open your mail client manually.');
    }
  }

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
    for (final controller in _codeControllers) {
      controller.clear();
    }
    if (mounted) {
      setState(() => _codeInvalid = markInvalid);
      _codeFocusNodes.first.requestFocus();
    }
  }

  void _onDigitChanged(int index, String value) {
    if (_codeInvalid) {
      setState(() => _codeInvalid = false);
    }

    // Handle full OTP paste (e.g. user pasted 6 digits into any box)
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      if (digits.isNotEmpty) {
        for (int i = 0; i < 6; i++) {
          if (i < digits.length) {
            _codeControllers[i].text = digits[i];
          }
        }
        final targetIndex = (digits.length >= 6) ? 5 : digits.length;
        _codeFocusNodes[targetIndex].requestFocus();
        if (digits.length >= 6) {
          _verify();
        }
        return;
      }
    }

    if (value.isNotEmpty) {
      if (index < 5) {
        _codeFocusNodes[index + 1].requestFocus();
      } else {
        // Last digit filled, dismiss keyboard and auto-verify
        FocusScope.of(context).unfocus();
        _verify();
      }
    }
  }

  Future<void> _showSuccessDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: Colors.green, size: 48),
              ),
              const SizedBox(height: 20),
              Text(
                'Verification Successful!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your email address has been verified successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Continue to Dashboard',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _messageFor(Object error) {
    final message = error.toString();
    if (message.contains('SocketException') ||
        message.contains('ClientException') ||
        message.contains('TimeoutException')) {
      return 'Could not connect to service. Please check your internet connection.';
    }
    if (message.contains('expired')) {
      return 'Verification code has expired. Please request a new code.';
    }
    if (message.contains('Invalid verification code') || message.contains('invalid')) {
      return 'Invalid verification code. Please check your email inbox.';
    }
    if (error is StateError) {
      return error.message;
    }
    return 'Verification failed. Please try again.';
  }

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
        foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 8),
              // Shield Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    width: 2,
                  ),
                ),
                child: const Icon(Icons.mark_email_read_outlined,
                    size: 40, color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              Text(
                'Enter Verification Code',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(text: 'We sent a 6-digit security code to\n'),
                    TextSpan(
                      text: widget.email,
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),

              // 6 OTP Digit Inputs
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
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: isDark ? AppColors.darkSurface : Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: _codeInvalid
                                  ? Colors.red
                                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                              width: 1.2,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: _codeInvalid ? Colors.red : AppColors.primary,
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
              const SizedBox(height: 36),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: CircularProgressIndicator(),
                )
              else ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _verify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                    child: const Text(
                      'Verify & Continue',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _openGmailInbox,
                    icon: const Icon(Icons.mail_outline_rounded, size: 20),
                    label: const Text('Open Gmail Inbox'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Resend Section with Countdown Timer
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Didn't receive the code? ",
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        fontSize: 13,
                      ),
                    ),
                    if (_cooldownSeconds > 0)
                      Text(
                        'Resend in ${_cooldownSeconds}s',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: () => _sendCode(),
                        child: const Text(
                          'Resend Code',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                  ],
                ),
              ],

              const SizedBox(height: 28),

              // Helpful Tip Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.amber.withValues(alpha: 0.1)
                      : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 20, color: Colors.amber),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tip: If the email doesn\'t arrive in 1-2 minutes, check your Spam or Promotions folder.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.amber.shade200 : const Color(0xFF92400E),
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
