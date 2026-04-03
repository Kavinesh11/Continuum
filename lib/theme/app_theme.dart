import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Primary palette ──
  static const Color primary = Color(0xFF008A8A);
  static const Color primaryDark = Color(0xFF005F5F);
  static const Color primaryLight = Color(0xFFB2DFDB);
  static const Color accent = Color(0xFF00BFA6);

  // ── Light Surface / Background ──
  static const Color scaffoldBg = Color(0xFFF4F7FA);
  static const Color cardSurface = Colors.white;

  // ── Dark Surface / Background ──
  static const Color darkScaffoldBg = Color(0xFF0F172A);
  static const Color darkCardSurface = Color(0xFF1E293B);
  static const Color darkCardSurfaceLight = Color(0xFF273548);

  // ── Text ──
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textHint = Color(0xFF94A3B8);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextHint = Color(0xFF64748B);

  // ── Misc ──
  static const Color dividerColor = Color(0xFFE2E8F0);
  static const Color darkDividerColor = Color(0xFF334155);
  static const Color dangerRed = Color(0xFFEF4444);
  static const Color warningOrange = Color(0xFFF59E0B);
  static const Color successGreen = Color(0xFF22C55E);

  // ── Gradients ──
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF008A8A), Color(0xFF005F5F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF0F172A), Color(0xFF1E3A5F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF00BFA6), Color(0xFF008A8A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Corner radius ──
  static const double radiusSm = 10.0;
  static const double radiusMd = 14.0;
  static const double radiusLg = 20.0;
  static const double radiusXl = 28.0;

  // ── Shadows ──
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get darkSoftShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.25),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get mediumShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> primaryGlow(double opacity) => [
        BoxShadow(
          color: primary.withOpacity(opacity),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ];

  // ── Card decoration shorthand ──
  static BoxDecoration get cardDecoration => BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(radiusMd),
        boxShadow: softShadow,
      );

  static BoxDecoration get darkCardDecoration => BoxDecoration(
        color: darkCardSurface,
        borderRadius: BorderRadius.circular(radiusMd),
        boxShadow: darkSoftShadow,
      );

  static BoxDecoration get elevatedCardDecoration => BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(radiusLg),
        boxShadow: mediumShadow,
      );

  // ── Helper: context-aware getters ──
  static Color scaffoldBgOf(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;

  static Color cardOf(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  static Color textPrimaryOf(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  static Color textSecondaryOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkTextSecondary
          : textSecondary;

  static Color textHintOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkTextHint
          : textHint;

  static Color dividerOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkDividerColor
          : dividerColor;

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static BoxDecoration cardDecorationOf(BuildContext context) => BoxDecoration(
        color: cardOf(context),
        borderRadius: BorderRadius.circular(radiusMd),
        boxShadow: isDark(context) ? darkSoftShadow : softShadow,
      );

  static List<BoxShadow> softShadowOf(BuildContext context) =>
      isDark(context) ? darkSoftShadow : softShadow;

  // ── Glassmorphism helpers ──
  static BoxDecoration glassDecoration({
    double opacity = 0.12,
    double borderOpacity = 0.2,
    double radius = radiusMd,
  }) =>
      BoxDecoration(
        color: Colors.white.withOpacity(opacity),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Colors.white.withOpacity(borderOpacity),
          width: 1.2,
        ),
      );

  static BoxDecoration glassDecorationOf(
    BuildContext context, {
    double radius = radiusMd,
  }) {
    final dark = isDark(context);
    return BoxDecoration(
      color: dark
          ? Colors.white.withOpacity(0.06)
          : Colors.white.withOpacity(0.55),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: dark
            ? Colors.white.withOpacity(0.08)
            : Colors.white.withOpacity(0.4),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(dark ? 0.15 : 0.04),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  /// Wrap child with a frosted glass container. Only use inside a Stack / over
  /// a gradient so the blur has a visual effect.
  static Widget glassCard({
    required BuildContext context,
    required Widget child,
    double sigmaX = 12,
    double sigmaY = 12,
    double radius = radiusMd,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY),
        child: Container(
          padding: padding,
          decoration: glassDecorationOf(context, radius: radius),
          child: child,
        ),
      ),
    );
  }

  // ── Theme Data ──
  static ThemeData get lightTheme {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        primary: primary,
        secondary: accent,
        surface: cardSurface,
        error: dangerRed,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: scaffoldBg,
    );

    return _applySharedTheme(base, Brightness.light);
  }

  static ThemeData get darkTheme {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.dark,
        primary: primary,
        secondary: accent,
        surface: darkCardSurface,
        error: dangerRed,
        onSurface: darkTextPrimary,
        onPrimary: Colors.white,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: darkScaffoldBg,
    );

    return _applySharedTheme(base, Brightness.dark);
  }

  static ThemeData _applySharedTheme(ThemeData base, Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final textPri = isLight ? textPrimary : darkTextPrimary;
    final textSec = isLight ? textSecondary : darkTextSecondary;
    final textHn = isLight ? textHint : darkTextHint;
    final card = isLight ? cardSurface : darkCardSurface;
    final divider = isLight ? dividerColor : darkDividerColor;

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          color: textPri,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textPri,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPri,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPri,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: textPri,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: textSec,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: primary,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textSec,
          letterSpacing: 0.5,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: card,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        iconTheme: IconThemeData(color: textPri),
        titleTextStyle: GoogleFonts.inter(
          color: primary,
          fontWeight: FontWeight.w800,
          fontSize: 18,
          letterSpacing: 0.3,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 72,
        indicatorColor: primary.withOpacity(0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: primary,
            );
          }
          return GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: textHn,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primary, size: 24);
          }
          return IconThemeData(color: textHn, size: 24);
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: primary, width: 1.8),
        ),
        hintStyle: GoogleFonts.inter(
          color: textHn,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: card,
        selectedColor: primary,
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        side: BorderSide(color: divider),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      dividerTheme: DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
