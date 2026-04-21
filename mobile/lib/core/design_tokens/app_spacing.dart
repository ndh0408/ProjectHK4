import 'package:flutter/material.dart';

/// 4-based spacing scale used across the app.
/// Mirrors the admin web `tokens.spacing` to keep both surfaces aligned.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
  static const double massive = 56;

  /// Default page horizontal padding.
  static const double pageX = xl;

  /// Default page vertical padding.
  static const double pageY = xxl;

  /// Default gap between stacked form fields.
  static const double field = lg;

  /// Default gap between related sections on a screen.
  static const double section = 28;

  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: pageX,
    vertical: pageY,
  );

  static const EdgeInsets cardPadding = EdgeInsets.all(xl);
  static const EdgeInsets compactCardPadding = EdgeInsets.all(md);
  static const EdgeInsets listItemPadding =
      EdgeInsets.symmetric(horizontal: lg, vertical: md);
  static const EdgeInsets dialogPadding = EdgeInsets.all(xxl);

  /// Vertical spacer helpers — convenience to avoid `SizedBox` soup.
  static const Widget gapXxs = SizedBox(height: xxs);
  static const Widget gapXs = SizedBox(height: xs);
  static const Widget gapSm = SizedBox(height: sm);
  static const Widget gapMd = SizedBox(height: md);
  static const Widget gapLg = SizedBox(height: lg);
  static const Widget gapXl = SizedBox(height: xl);
  static const Widget gapXxl = SizedBox(height: xxl);
  static const Widget gapXxxl = SizedBox(height: xxxl);

  static const Widget hgapXs = SizedBox(width: xs);
  static const Widget hgapSm = SizedBox(width: sm);
  static const Widget hgapMd = SizedBox(width: md);
  static const Widget hgapLg = SizedBox(width: lg);
  static const Widget hgapXl = SizedBox(width: xl);
}
