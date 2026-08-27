import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/app_update_service.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MeterUnitApp());
}

class MeterUnitApp extends StatelessWidget {
  const MeterUnitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MeterPro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const _AppUpdateGate(
        child: _AuthGate(),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService.instance.authStateChanges,
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) return const LoginScreen();
        return FutureBuilder<bool>(
          future: AuthService.instance.isOtpVerified(),
          builder: (context, verified) => verified.data == true
              ? const DashboardScreen()
              : const LoginScreen(),
        );
      },
    );
  }
}

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
