import 'package:flutter/material.dart';

abstract final class AppShadows {
  static const List<BoxShadow> xs = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> sm = [
    BoxShadow(
      color: Color(0x0F0F172A),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> md = [
    BoxShadow(
      color: Color(0x141E293B),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> lg = [
    BoxShadow(
      color: Color(0x1A0F172A),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> primary = [
    BoxShadow(
      color: Color(0x40667EEA),
      blurRadius: 20,
      offset: Offset(0, 8),
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
