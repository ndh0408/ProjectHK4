import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Semantic text styles. Prefer these over inline `TextStyle` in screens.
/// Colors default to theme colors; override only when contrast requires it.
abstract final class AppTypography {
  static TextStyle get display => GoogleFonts.plusJakartaSans(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.05,
        letterSpacing: -0.9,
      );

  static TextStyle get h1 => GoogleFonts.plusJakartaSans(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 1.08,
        letterSpacing: -0.7,
      );

  static TextStyle get h2 => GoogleFonts.plusJakartaSans(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.14,
        letterSpacing: -0.45,
      );

  static TextStyle get h3 => GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.22,
        letterSpacing: -0.25,
      );

  static TextStyle get h4 => GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.3,
      );

  static TextStyle get bodyLg => GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.6,
      );

  static TextStyle get body => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.55,
      );

  static TextStyle get label => GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.4,
      );

  static TextStyle get caption => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.4,
      );

  static TextStyle get button => GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: 0.1,
      );

  static TextStyle get overline => GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: 0.6,
      );
}
