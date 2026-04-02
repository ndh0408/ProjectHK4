import 'package:flutter/material.dart';

class Responsive {
  Responsive._();

  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileBreakpoint;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktopBreakpoint;

  static double screenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double screenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;

  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop(context)) return desktop ?? tablet ?? mobile;
    if (isTablet(context)) return tablet ?? mobile;
    return mobile;
  }

  static EdgeInsets padding(BuildContext context) {
    return EdgeInsets.symmetric(
      horizontal: value(context, mobile: 16.0, tablet: 24.0, desktop: 32.0),
      vertical: value(context, mobile: 12.0, tablet: 16.0, desktop: 20.0),
    );
  }

  static double horizontalPadding(BuildContext context) {
    return value(context, mobile: 16.0, tablet: 24.0, desktop: 32.0);
  }

  static double cardWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < mobileBreakpoint) {
      return screenWidth * 0.75;
    } else if (screenWidth < tabletBreakpoint) {
      return screenWidth * 0.45;
    }
    return 320;
  }

  static int gridColumns(BuildContext context) {
    return value(context, mobile: 2, tablet: 3, desktop: 4);
  }

  static double fontScale(BuildContext context) {
    return value(context, mobile: 1.0, tablet: 1.1, desktop: 1.15);
  }

  static double iconSize(BuildContext context, {double base = 24}) {
    return base * value(context, mobile: 1.0, tablet: 1.15, desktop: 1.25);
  }

  static double spacing(BuildContext context, {double base = 8}) {
    return base * value(context, mobile: 1.0, tablet: 1.25, desktop: 1.5);
  }

  static EdgeInsets safeArea(BuildContext context) {
    return MediaQuery.of(context).padding;
  }

  static bool isKeyboardVisible(BuildContext context) {
    return MediaQuery.of(context).viewInsets.bottom > 0;
  }

  static double bottomNavHeight(BuildContext context) {
    return 60 + MediaQuery.of(context).padding.bottom;
  }
}

extension ResponsiveExtension on num {
  double w(BuildContext context) =>
      this * MediaQuery.of(context).size.width / 375;

  double h(BuildContext context) =>
      this * MediaQuery.of(context).size.height / 812;

  double sp(BuildContext context) {
    final scale = MediaQuery.of(context).textScaler.scale(1);
    return this * scale;
  }
}
