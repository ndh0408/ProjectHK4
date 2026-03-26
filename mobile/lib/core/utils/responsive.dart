import 'package:flutter/material.dart';

/// Responsive utilities for adapting UI across different screen sizes
class Responsive {
  Responsive._();

  // Breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  /// Check if screen is mobile size
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileBreakpoint;

  /// Check if screen is tablet size
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  /// Check if screen is desktop size
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktopBreakpoint;

  /// Get screen width
  static double screenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  /// Get screen height
  static double screenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;

  /// Get responsive value based on screen size
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

  /// Get responsive padding
  static EdgeInsets padding(BuildContext context) {
    return EdgeInsets.symmetric(
      horizontal: value(context, mobile: 16.0, tablet: 24.0, desktop: 32.0),
      vertical: value(context, mobile: 12.0, tablet: 16.0, desktop: 20.0),
    );
  }

  /// Get responsive horizontal padding
  static double horizontalPadding(BuildContext context) {
    return value(context, mobile: 16.0, tablet: 24.0, desktop: 32.0);
  }

  /// Get responsive card width for horizontal lists
  static double cardWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < mobileBreakpoint) {
      return screenWidth * 0.75; // 75% of screen on mobile
    } else if (screenWidth < tabletBreakpoint) {
      return screenWidth * 0.45; // 45% on tablet
    }
    return 320; // Fixed width on desktop
  }

  /// Get number of grid columns
  static int gridColumns(BuildContext context) {
    return value(context, mobile: 2, tablet: 3, desktop: 4);
  }

  /// Get responsive font scale factor
  static double fontScale(BuildContext context) {
    return value(context, mobile: 1.0, tablet: 1.1, desktop: 1.15);
  }

  /// Get responsive icon size
  static double iconSize(BuildContext context, {double base = 24}) {
    return base * value(context, mobile: 1.0, tablet: 1.15, desktop: 1.25);
  }

  /// Get responsive spacing
  static double spacing(BuildContext context, {double base = 8}) {
    return base * value(context, mobile: 1.0, tablet: 1.25, desktop: 1.5);
  }

  /// Get safe area padding
  static EdgeInsets safeArea(BuildContext context) {
    return MediaQuery.of(context).padding;
  }

  /// Check if keyboard is visible
  static bool isKeyboardVisible(BuildContext context) {
    return MediaQuery.of(context).viewInsets.bottom > 0;
  }

  /// Get bottom nav bar height (accounting for safe area)
  static double bottomNavHeight(BuildContext context) {
    return 60 + MediaQuery.of(context).padding.bottom;
  }
}

/// Extension for responsive sizing
extension ResponsiveExtension on num {
  /// Responsive width
  double w(BuildContext context) =>
      this * MediaQuery.of(context).size.width / 375;

  /// Responsive height
  double h(BuildContext context) =>
      this * MediaQuery.of(context).size.height / 812;

  /// Responsive font size
  double sp(BuildContext context) {
    final scale = MediaQuery.of(context).textScaler.scale(1);
    return this * scale;
  }
}
