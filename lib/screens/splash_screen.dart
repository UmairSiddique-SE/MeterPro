import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Full-screen animated splash that plays on every cold start.
/// After [_splashDuration] it calls [onComplete].
class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── controllers ──────────────────────────────
  late final AnimationController _orbitCtrl;
  late final AnimationController _entryCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _exitCtrl;

  // ── animations ───────────────────────────────
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _taglineOpacity;
  late final Animation<Offset> _taglineSlide;
  late final Animation<double> _ringOpacity;
  late final Animation<double> _ringScale;
  late final Animation<double> _exitOpacity;
  late final Animation<double> _pulse;

  static const Duration _splashDuration = Duration(milliseconds: 2800);

  @override
  void initState() {
    super.initState();

    _orbitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _logoScale = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
    );

    _logoOpacity = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );

    _taglineOpacity = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
    );

    _taglineSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
    ));

    _ringOpacity = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
    );

    _ringScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _pulse = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitCtrl, curve: Curves.easeInOut),
    );

    _entryCtrl.forward();

    Future.delayed(_splashDuration, () {
      if (!mounted) return;
      _exitCtrl.forward().then((_) {
        if (mounted) widget.onComplete();
      });
    });
  }

  @override
  void dispose() {
    _orbitCtrl.dispose();
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _exitOpacity,
      child: Scaffold(
        backgroundColor: AppColors.navy900,
        body: Stack(
          children: [
            // ── Background gradient radials ──
            Positioned.fill(
              child: CustomPaint(painter: _BgPainter()),
            ),

            // ── Orbiting ring ──
            Positioned.fill(
              child: AnimatedBuilder(
                animation: Listenable.merge([_orbitCtrl, _ringOpacity, _ringScale]),
                builder: (_, __) {
                  return FadeTransition(
                    opacity: _ringOpacity,
                    child: ScaleTransition(
                      scale: _ringScale,
                      child: CustomPaint(
                        painter: _OrbitPainter(_orbitCtrl.value),
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Center content ──
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pulsing logo
                  AnimatedBuilder(
                    animation: Listenable.merge([_logoScale, _logoOpacity, _pulse]),
                    builder: (_, __) {
                      return FadeTransition(
                        opacity: _logoOpacity,
                        child: ScaleTransition(
                          scale: _logoScale,
                          child: Transform.scale(
                            scale: _pulse.value,
                            child: _LogoWidget(),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  // App name
                  FadeTransition(
                    opacity: _taglineOpacity,
                    child: SlideTransition(
                      position: _taglineSlide,
                      child: Column(
                        children: [
                          RichText(
                            text: const TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Meter',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 36,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                TextSpan(
                                  text: 'Pro',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 36,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.amber,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Smart Electricity Tracker',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withValues(alpha: 0.55),
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Bottom loading dots ──
            Positioned(
              bottom: 64,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _taglineOpacity,
                child: _LoadingDots(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Logo widget ──────────────────────────────────────────────────────────────
class _LogoWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: AppColors.blueGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.6),
            blurRadius: 40,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: AppColors.amber.withValues(alpha: 0.2),
            blurRadius: 60,
            spreadRadius: 10,
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
      ),
    );
  }
}

// ── Animated loading dots ─────────────────────────────────────────────────────
class _LoadingDots extends StatefulWidget {
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with TickerProviderStateMixin {
  late final List<AnimationController> _ctrls;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(3, (i) {
      final c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
      Future.delayed(Duration(milliseconds: i * 180), () {
        if (mounted) c.repeat(reverse: true);
      });
      return c;
    });
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _ctrls[i],
          builder: (_, __) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 6,
            height: 6 + _ctrls[i].value * 8,
            decoration: BoxDecoration(
              color: AppColors.amber
                  .withValues(alpha: 0.4 + _ctrls[i].value * 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }),
    );
  }
}

// ── Custom painters ──────────────────────────────────────────────────────────
class _BgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.primary.withValues(alpha: 0.18),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.2, size.height * 0.2),
        radius: size.width * 0.6,
      ));

    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.amber.withValues(alpha: 0.10),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.85, size.height * 0.75),
        radius: size.width * 0.5,
      ));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint1);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OrbitPainter extends CustomPainter {
  final double t;
  _OrbitPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = AppColors.primary.withValues(alpha: 0.12);

    // rings
    for (final r in [100.0, 160.0, 220.0]) {
      canvas.drawCircle(center, r, paint);
    }

    // orbiting dots
    final dotPaint = Paint()..style = PaintingStyle.fill;
    final dots = [
      (radius: 100.0, speed: 1.0, color: AppColors.amber, size: 5.0),
      (radius: 160.0, speed: -0.6, color: AppColors.cyan, size: 4.0),
      (radius: 220.0, speed: 0.4, color: AppColors.primary, size: 3.5),
    ];

    for (final d in dots) {
      final angle = 2 * math.pi * t * d.speed;
      final dx = center.dx + d.radius * math.cos(angle);
      final dy = center.dy + d.radius * math.sin(angle);
      dotPaint.color = d.color.withValues(alpha: 0.9);
      // glow
      dotPaint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(dx, dy), d.size * 1.5, dotPaint);
      dotPaint.maskFilter = null;
      dotPaint.color = d.color;
      canvas.drawCircle(Offset(dx, dy), d.size, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter old) => old.t != t;
}
