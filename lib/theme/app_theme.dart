import 'package:flutter/material.dart';

class AppTheme {
  // ── Trust (navy blue) palette — matches website trust-* ───────
  static const Color primary       = Color(0xFF1E3A8A); // trust-700
  static const Color primaryLight  = Color(0xFF2563EB); // trust-500
  static const Color primaryDark   = Color(0xFF1E3577); // trust-800
  static const Color primaryDeep   = Color(0xFF172554); // trust-900

  // ── Surface / background ──────────────────────────────────────
  static const Color background    = Color(0xFFEFF4FF); // trust-50
  static const Color surface       = Color(0xFFFFFFFF); // white
  static const Color card          = Color(0xFFFFFFFF);
  static const Color surfaceMuted  = Color(0xFFDBE6FE); // trust-100

  // ── Text ──────────────────────────────────────────────────────
  static const Color textDark      = Color(0xFF172554); // trust-900
  static const Color textMedium    = Color(0xFF64748B); // slate-500
  static const Color textSubtle    = Color(0xFF94A3B8); // slate-400

  // ── Icon / accent backgrounds ─────────────────────────────────
  static const Color iconBg        = Color(0xFFDBE6FE); // trust-100
  static const Color progressBg    = Color(0xFFBFD2FE); // trust-200
  static const Color glowColor     = Color(0x301E3A8A); // trust-700 @ 19%

  // ── Status — safe (green) ─────────────────────────────────────
  static const Color safeGreen     = Color(0xFF16A34A); // status-safe
  static const Color safeBg        = Color(0xFFDCFCE7); // status-safe-bg
  static const Color safeFg        = Color(0xFF14532D); // status-safe-fg

  // ── Status — warning (amber) ──────────────────────────────────
  static const Color warningYellow = Color(0xFFF59E0B); // status-warn
  static const Color warnBg        = Color(0xFFFEF3C7); // status-warn-bg
  static const Color warnFg        = Color(0xFF78350F); // status-warn-fg

  // ── Status — danger (red) ─────────────────────────────────────
  static const Color dangerRed     = Color(0xFFDC2626); // status-danger
  static const Color dangerBg      = Color(0xFFFEE2E2); // status-danger-bg
  static const Color dangerFg      = Color(0xFF7F1D1D); // status-danger-fg

  // ── Misc ──────────────────────────────────────────────────────
  static const Color dialogBg      = Color(0xFFFFFFFF);
  static const Color appInfoSep    = Color(0xFFDBE6FE); // trust-100

  static const String _fontFamily  = 'Pretendard';

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      fontFamily: _fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        surface: card,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: primary),
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          color: textDark,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Color(0xFF6B8FD1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 18),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFBFD2FE), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFBFD2FE), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: dangerRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: dangerRed),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        labelStyle: const TextStyle(
          color: primary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          fontFamily: _fontFamily,
        ),
      ),
    );
  }
}
