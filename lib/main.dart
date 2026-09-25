import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/splash_screen.dart';
import 'services/app_update_service.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {
    // Fallback defaults will be used if .env is not found
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
      builder: (context, _) {
        return MaterialApp(
          title: 'MeterPro',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: _themeProvider.mode,
          home: _AppUpdateGate(
            child: _SplashGate(themeProvider: _themeProvider),
          ),
        );
      },
    );
  }
}

// ── Splash → Auth gate ───────────────────────────────────────────────────────
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
      return SplashScreen(
        onComplete: () => setState(() => _splashDone = true),
      );
    }
    return _AuthGate(themeProvider: widget.themeProvider);
  }
}

// ── Auth gate ────────────────────────────────────────────────────────────────
class _AuthGate extends StatelessWidget {
  final ThemeProvider themeProvider;
  const _AuthGate({required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService.instance.authStateChanges,
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) return const LoginScreen();

        return FutureBuilder<bool>(
          future: AuthService.instance.isOtpVerified(),
          builder: (context, verified) {
            if (verified.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return verified.data == true
                ? DashboardScreen(themeProvider: themeProvider)
                : const LoginScreen();
          },
        );
      },
    );
  }
}

// ── App update gate ──────────────────────────────────────────────────────────
class _AppUpdateGate extends StatefulWidget {
  final Widget child;
  const _AppUpdateGate({required this.child});

  @override
  State<_AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<_AppUpdateGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppUpdateService.instance.checkAndShow(context);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
