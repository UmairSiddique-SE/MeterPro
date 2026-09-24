import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ─────────────────────────────────────────────
///  MeterPro Design System — Full Premium Theme
///  Supports Light + Dark modes
/// ─────────────────────────────────────────────
class AppColors {
  AppColors._();

  // ── Brand / Primary ──
  static const Color navy900 = Color(0xFF0A0F1E);
  static const Color navy800 = Color(0xFF0D1530);
  static const Color navy700 = Color(0xFF111B3A);
  static const Color navy600 = Color(0xFF162248);
  static const Color navy500 = Color(0xFF1E2E60);
  static const Color primary = Color(0xFF2445C8); // vivid electric blue
  static const Color primaryLight = Color(0xFF3D5EE8);
  static const Color primaryGlow = Color(0x402445C8);

  // ── Accent ──
  static const Color amber = Color(0xFFFFB020); // energy/bill highlight
  static const Color amberDim = Color(0xFFCC8A00);
  static const Color amberGlow = Color(0x33FFB020);
  static const Color green = Color(0xFF22C55E); // active/success
  static const Color greenGlow = Color(0x2222C55E);
  static const Color red = Color(0xFFEF4444);
  static const Color redGlow = Color(0x22EF4444);
  static const Color cyan = Color(0xFF06B6D4); // scan/tech accent

  // ── Light Mode ──
  static const Color lightBg = Color(0xFFF5F7FF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurface2 = Color(0xFFF0F3FF);
  static const Color lightBorder = Color(0xFFE2E8FF);
  static const Color lightTextPrimary = Color(0xFF0A0F1E);
  static const Color lightTextSecondary = Color(0xFF4A5580);
  static const Color lightTextMuted = Color(0xFF8B93B3);

  // ── Dark Mode ──
  static const Color darkBg = Color(0xFF080C18);
  static const Color darkSurface = Color(0xFF0E1326);
  static const Color darkSurface2 = Color(0xFF141A30);
  static const Color darkSurface3 = Color(0xFF1A2138);
  static const Color darkBorder = Color(0xFF1E2848);
  static const Color darkTextPrimary = Color(0xFFECEEF8);
  static const Color darkTextSecondary = Color(0xFF8B93B3);
  static const Color darkTextMuted = Color(0xFF4A5580);

  // ── Legacy Compatibility Aliases ──
  static const Color textPrimary = lightTextPrimary;
  static const Color textSecondary = lightTextSecondary;
  static const Color textMuted = lightTextMuted;
  static const Color border = lightBorder;
  static const Color cardBg = lightSurface;
  static const Color cardBackground = lightSurface;
  static const Color surface = lightSurface;
  static const Color background = lightBg;
  static const Color inputFill = lightSurface2;
  static const Color accentGreen = green;
  static const Color accentOrange = amber;
  static const Color accentRed = red;
  static const Color accentCyan = cyan;
  static const Color accentBlue = primary;
  static const Color primaryDark = navy700;
  static const Color divider = lightBorder;

  // ── Gradients ──
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navy800, navy600, Color(0xFF1E2E60)],
  );

  static const LinearGradient premiumGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A2448), Color(0xFF0D1530)],
  );

  static const LinearGradient amberGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFB020), Color(0xFFFF8C00)],
  );

  static const LinearGradient blueGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2445C8), Color(0xFF1A35A0)],
  );

  static const LinearGradient headerGradient = brandGradient;

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [lightSurface, lightSurface2],
  );

  static const LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x20FFFFFF), Color(0x05FFFFFF)],
  );
}

class AppTheme {
  AppTheme._();

  // ─── LIGHT THEME ─────────────────────────────
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.amber,
        tertiary: AppColors.cyan,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightTextPrimary,
        brightness: Brightness.light,
      ),
    );
    return base.copyWith(
      textTheme: _buildTextTheme(base.textTheme, AppColors.lightTextPrimary),
      inputDecorationTheme: _inputTheme(
        fill: AppColors.lightSurface,
        border: AppColors.lightBorder,
        primary: AppColors.primary,
        muted: AppColors.lightTextMuted,
      ),
      elevatedButtonTheme: _elevatedButtonTheme(),
      outlinedButtonTheme: _outlinedButtonTheme(AppColors.lightBorder),
      cardTheme: _cardTheme(AppColors.lightSurface, AppColors.lightBorder),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.lightBg,
        foregroundColor: AppColors.lightTextPrimary,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.lightTextPrimary,
        ),
        iconTheme: const IconThemeData(color: AppColors.lightTextPrimary),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightBorder,
        thickness: 1,
        space: 1,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        side: const BorderSide(color: AppColors.lightBorder, width: 1.5),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.navy800,
        contentTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.lightTextPrimary,
        ),
      ),
    );
  }

  // ─── DARK THEME ──────────────────────────────
  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.amber,
        tertiary: AppColors.cyan,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkTextPrimary,
        brightness: Brightness.dark,
      ),
    );
    return base.copyWith(
      textTheme: _buildTextTheme(base.textTheme, AppColors.darkTextPrimary),
      inputDecorationTheme: _inputTheme(
        fill: AppColors.darkSurface2,
        border: AppColors.darkBorder,
        primary: AppColors.primaryLight,
        muted: AppColors.darkTextMuted,
      ),
      elevatedButtonTheme: _elevatedButtonTheme(),
      outlinedButtonTheme: _outlinedButtonTheme(AppColors.darkBorder),
      cardTheme: _cardTheme(AppColors.darkSurface, AppColors.darkBorder),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.darkBg,
        foregroundColor: AppColors.darkTextPrimary,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.darkTextPrimary,
        ),
        iconTheme: const IconThemeData(color: AppColors.darkTextPrimary),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkBorder,
        thickness: 1,
        space: 1,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primaryLight;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        side: const BorderSide(color: AppColors.darkBorder, width: 1.5),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkSurface3,
        contentTextStyle: GoogleFonts.inter(color: AppColors.darkTextPrimary, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.darkTextPrimary,
        ),
      ),
    );
  }

  // ─── HELPERS ─────────────────────────────────
  static TextTheme _buildTextTheme(TextTheme base, Color primaryColor) {
    return GoogleFonts.interTextTheme(base).copyWith(
      displayLarge: GoogleFonts.poppins(
        fontSize: 48, fontWeight: FontWeight.w800, color: primaryColor, letterSpacing: -1),
      displayMedium: GoogleFonts.poppins(
        fontSize: 36, fontWeight: FontWeight.w800, color: primaryColor, letterSpacing: -0.5),
      headlineLarge: GoogleFonts.poppins(
        fontSize: 28, fontWeight: FontWeight.w700, color: primaryColor),
      headlineMedium: GoogleFonts.poppins(
        fontSize: 22, fontWeight: FontWeight.w700, color: primaryColor),
      headlineSmall: GoogleFonts.poppins(
        fontSize: 18, fontWeight: FontWeight.w600, color: primaryColor),
      titleLarge: GoogleFonts.poppins(
        fontSize: 16, fontWeight: FontWeight.w700, color: primaryColor),
      titleMedium: GoogleFonts.inter(
        fontSize: 15, fontWeight: FontWeight.w600, color: primaryColor),
      titleSmall: GoogleFonts.inter(
        fontSize: 13, fontWeight: FontWeight.w600, color: primaryColor),
      bodyLarge: GoogleFonts.inter(fontSize: 16, color: primaryColor),
      bodyMedium: GoogleFonts.inter(fontSize: 14),
      bodySmall: GoogleFonts.inter(fontSize: 12),
      labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      labelMedium: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
      labelSmall: GoogleFonts.inter(
        fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8),
    );
  }

  static InputDecorationTheme _inputTheme({
    required Color fill,
    required Color border,
    required Color primary,
    required Color muted,
  }) {
    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.red, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.red, width: 2),
      ),
      hintStyle: GoogleFonts.inter(color: muted, fontSize: 14),
      prefixIconColor: muted,
      suffixIconColor: muted,
    );
  }

  static ElevatedButtonThemeData _elevatedButtonTheme() {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedButtonTheme(Color border) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide(color: border, width: 1.5),
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    );
  }

  static CardThemeData _cardTheme(Color surface, Color border) {
    return CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: border),
      ),
    );
  }
}

/// Helper extension to easily access theme brightness
extension AppThemeExt on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get surfaceColor => isDark ? AppColors.darkSurface : AppColors.lightSurface;
  Color get surface2Color => isDark ? AppColors.darkSurface2 : AppColors.lightSurface2;
  Color get borderColor => isDark ? AppColors.darkBorder : AppColors.lightBorder;
  Color get textPrimary => isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
  Color get textSecondary => isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
  Color get textMuted => isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
  Color get bgColor => isDark ? AppColors.darkBg : AppColors.lightBg;
}
