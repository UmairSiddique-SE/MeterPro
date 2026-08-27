import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    if (widget.sendInitialCode) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _resend(isInitial: true));
    }
  }

  @override
  void dispose() {
    for (final controller in _codeControllers) {
      controller.dispose();
    }
    for (final focusNode in _codeFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeControllers.map((controller) => controller.text).join();
    if (code.length != 6) {
      _show('Enter the 6-digit code.');
      return;
    }

    setState(() => _loading = true);
    try {
      await AuthService.instance.verifyOtp(code);

      final user = AuthService.instance.currentUser;
      if (user == null) throw StateError('Your session has expired.');
      await AuthService.instance.saveProfile(
        user: user,
        email: widget.email,
        displayName: widget.name,
        phoneNumber: widget.phoneNumber,
      );

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
      _show(_messageFor(error,
          fallback:
              'That code is invalid or has expired. Request a new one and try again.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend({bool isInitial = false}) async {
    setState(() => _loading = true);
    try {
      await AuthService.instance.requestOtp(
        email: widget.email,
        name: widget.name,
      );
      if (!mounted) return;
      _clearCode();
      _show(isInitial
          ? 'A verification code has been sent to ${widget.email}.'
          : 'A new code has been sent to ${widget.email}.');
    } catch (error) {
      _show(_messageFor(error,
          fallback: 'We could not send a code. Please try again shortly.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openGmailInbox() async {
    final gmailApp = Uri.parse('googlegmail://');
    final gmailWeb = Uri.parse('https://mail.google.com/mail/u/0/#inbox');
    if (await canLaunchUrl(gmailApp)) {
      await launchUrl(gmailApp, mode: LaunchMode.externalApplication);
      return;
    }
    await launchUrl(gmailWeb, mode: LaunchMode.externalApplication);
  }

  void _show(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _clearCode({bool markInvalid = false}) {
    for (final controller in _codeControllers) {
      controller.clear();
    }
    if (mounted) setState(() => _codeInvalid = markInvalid);
    _codeFocusNodes.first.requestFocus();
  }

  Future<void> _showSuccessDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.green, size: 72),
            const SizedBox(height: 16),
            const Text('Login successful!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Your email has been verified.',
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _messageFor(Object error, {required String fallback}) {
    final message = error.toString();
    if (message.contains('EmailJS private key is missing')) {
      return 'EmailJS private key is not configured. Start the app with the EMAILJS_PRIVATE_KEY dart define.';
    }
    if (message.contains('EmailJS failed')) {
      final details = message.replaceFirst('Bad state: EmailJS failed ', '');
      return 'EmailJS rejected the request: $details';
    }
    if (message.contains('SocketException') ||
        message.contains('ClientException') ||
        message.contains('TimeoutException')) {
      return 'Could not reach the verification service. Check your internet connection and try again.';
    }
    if (message.contains('resource-exhausted')) {
      return 'Please wait one minute before requesting another code.';
    }
    if (message.contains('unauthenticated')) {
      return 'Your session has expired. Please sign in again.';
    }
    if (message.contains('expired')) {
      return 'That code has expired. Request a new one and try again.';
    }
    if (message.contains('invalid')) {
      return 'That code is invalid. Please check your email inbox and try again.';
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Security Verification',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield_outlined,
                  size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            Text('Check your email',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 14, height: 1.5),
                children: [
                  const TextSpan(
                      text: 'We have sent a 6-digit verification code to\n'),
                  TextSpan(
                    text: widget.email,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            Row(
              children: List.generate(6, (index) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: index == 5 ? 0 : 8),
                    child: TextField(
                      controller: _codeControllers[index],
                      focusNode: _codeFocusNodes[index],
                      autofocus: index == 0,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _codeInvalid ? Colors.red : AppColors.border,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color:
                                _codeInvalid ? Colors.red : AppColors.primary,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        if (_codeInvalid) setState(() => _codeInvalid = false);
                        if (value.isNotEmpty && index < 5) {
                          _codeFocusNodes[index + 1].requestFocus();
                        }
                        if (value.isEmpty && index > 0) {
                          _codeFocusNodes[index - 1].requestFocus();
                        }
                      },
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 48),

            if (_loading)
              const CircularProgressIndicator()
            else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _verify,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Verify & Login',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _openGmailInbox,
                icon: const Icon(Icons.mark_email_unread_outlined),
                label: const Text('Open Gmail Inbox'),
              ),
              const SizedBox(height: 12),
              const Text("Didn't receive the code?",
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              TextButton(
                onPressed: _resend,
                child: const Text('Resend New Code',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],

            const SizedBox(height: 20),
            // Footer help
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 18, color: Colors.amber),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tip: Check your Spam or Junk folder if the email doesn\'t arrive in 1 minute.',
                      style: TextStyle(fontSize: 12, color: Colors.brown),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
