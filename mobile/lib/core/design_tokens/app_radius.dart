import 'package:flutter/material.dart';

abstract final class AppRadius {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double pill = 999;

  static const BorderRadius allXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius allSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius allMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius allLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius allXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius allPill = BorderRadius.all(Radius.circular(pill));

  static const RoundedRectangleBorder cardShape = RoundedRectangleBorder(
    borderRadius: allLg,
  );
  static const RoundedRectangleBorder dialogShape = RoundedRectangleBorder(
    borderRadius: allXl,
  );
  static const RoundedRectangleBorder buttonShape = RoundedRectangleBorder(
    borderRadius: allMd,
  );
  static const RoundedRectangleBorder inputShape = RoundedRectangleBorder(
    borderRadius: allMd,
  );
}
