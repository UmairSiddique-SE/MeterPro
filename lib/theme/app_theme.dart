import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ─────────────────────────────────────────────
///  MeterPro Design System — Full Aesthetic Theme
/// ─────────────────────────────────────────────
class AppColors {
  AppColors._();

  // ── Brand / Primary ──
  static const Color navy900 = Color(0xFF070B19);
  static const Color navy800 = Color(0xFF0F172A);
  static const Color navy700 = Color(0xFF1E293B);
  static const Color navy600 = Color(0xFF334155);
  static const Color navy500 = Color(0xFF475569);

  // Vibrant Electric Sapphire & Royal Blue
  static const Color primary = Color(0xFF1D4ED8); // Rich Professional Blue
  static const Color primaryDark = Color(0xFF1E40AF);
  static const Color primaryLight = Color(0xFF2563EB);
  static const Color primarySoft = Color(0xFFEFF6FF);
  static const Color primaryGlow = Color(0x351D4ED8);

  // ── Aesthetic Accents ──
  static const Color amber = Color(0xFFF59E0B); // Amber / Gold Energy
  static const Color amberDark = Color(0xFFD97706);
  static const Color amberSoft = Color(0xFFFFFBEB);
  static const Color amberGlow = Color(0x30F59E0B);

  static const Color green = Color(0xFF10B981); // Emerald Green Active
  static const Color greenDark = Color(0xFF059669);
  static const Color greenSoft = Color(0xFFECFDF5);
  static const Color greenGlow = Color(0x2510B981);

  static const Color red = Color(0xFFEF4444); // Crimson Alert
  static const Color redSoft = Color(0xFFFEF2F2);
  static const Color redGlow = Color(0x25EF4444);

  static const Color cyan = Color(0xFF06B6D4); // Cyber Cyan
  static const Color purple = Color(0xFF8B5CF6); // Royal Violet

  // ── Light Mode Surface ──
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurface2 = Color(0xFFF1F5F9);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // ── Dark Mode Surface ──
  static const Color darkBg = Color(0xFF080D1A);
  static const Color darkSurface = Color(0xFF0F172A);
  static const Color darkSurface2 = Color(0xFF1E293B);
  static const Color darkSurface3 = Color(0xFF334155);
  static const Color darkBorder = Color(0xFF1E293B);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);

  // ── Aliases ──
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
  static const Color accentPurple = purple;
  static const Color accentBlue = primary;
  static const Color divider = lightBorder;

  // ── Aesthetic Gradients ──
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8), Color(0xFF1E40AF)],
  );

  static const LinearGradient premiumGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
  );

  static const LinearGradient amberGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
  );

  static const LinearGradient blueGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
  );

  static const LinearGradient emeraldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF10B981), Color(0xFF059669)],
  );

  static const LinearGradient headerGradient = brandGradient;

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [lightSurface, Color(0xFFF8FAFC)],
  );

  static const LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x25FFFFFF), Color(0x08FFFFFF)],
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
          fontSize: 18,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: const BorderSide(color: AppColors.lightBorder, width: 1.5),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.navy900,
        contentTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

  // ─── DARK THEME ─────────────────────────────
  static ThemeData get dark => light;

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
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.red, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
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
        borderRadius: BorderRadius.circular(24),
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
