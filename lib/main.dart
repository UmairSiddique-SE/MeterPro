import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/otp_verification_screen.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MeterUnitApp());
}

class MeterUnitApp extends StatefulWidget {
  const MeterUnitApp({super.key});
  @override
  State<MeterUnitApp> createState() => _MeterUnitAppState();
}

class _MeterUnitAppState extends State<MeterUnitApp> {
  final ThemeProvider _themeProvider = ThemeProvider();

  @override
  void dispose() {
    _themeProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _themeProvider,
      builder: (context, _) => MaterialApp(
        title: 'MeterPro',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.light,
        themeMode: ThemeMode.light,
        home: _SplashGate(themeProvider: _themeProvider),
      ),
    );
  }
}

class _SplashGate extends StatefulWidget {
  final ThemeProvider themeProvider;
  const _SplashGate({required this.themeProvider});
  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> {
  bool _splashDone = false;
  @override
  Widget build(BuildContext context) {
    if (!_splashDone) {
      return SplashScreen(onComplete: () => setState(() => _splashDone = true));
    }
    return _AuthGate(themeProvider: widget.themeProvider);
  }
}

class _AuthGate extends StatelessWidget {
  final ThemeProvider themeProvider;
  const _AuthGate({required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService.instance.authStateChanges,
      builder: (context, snapshot) {
        // Still loading auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        // Not logged in — show login
        if (user == null) return const LoginScreen();

        // Logged in — check OTP verification
        return FutureBuilder<bool>(
          future: AuthService.instance.isOtpVerified(),
          builder: (context, verified) {
            if (verified.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (verified.data == true) {
              // Fully verified — go to dashboard
              return DashboardScreen(themeProvider: themeProvider);
            }
            // Logged in but NOT verified — show OTP screen
            // sendInitialCode: true so a fresh code is sent automatically
            return OtpVerificationScreen(
              email: user.email ?? '',
              sendInitialCode: true,
            );
          },
        );
      },
    );
  }
}

