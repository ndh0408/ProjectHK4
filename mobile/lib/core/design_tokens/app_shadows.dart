import 'package:flutter/material.dart';

abstract final class AppShadows {
  static const List<BoxShadow> xs = [
    BoxShadow(
      color: Color(0x0A0F172A),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> sm = [
    BoxShadow(
      color: Color(0x100F172A),
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
  ];

  static const List<BoxShadow> md = [
    BoxShadow(
      color: Color(0x160F172A),
      blurRadius: 28,
      offset: Offset(0, 10),
    ),
  ];

  static const List<BoxShadow> lg = [
    BoxShadow(
      color: Color(0x1D0F172A),
      blurRadius: 44,
      offset: Offset(0, 18),
    ),
  ];

  static const List<BoxShadow> primary = [
    BoxShadow(
      color: Color(0x2B1858E8),
      blurRadius: 28,
      offset: Offset(0, 14),
    ),
  ];
}

abstract final class AppElevation {
  static const double z0 = 0;
  static const double z1 = 1;
  static const double z2 = 2;
  static const double z3 = 4;
  static const double z4 = 8;
  static const double z5 = 12;
}
