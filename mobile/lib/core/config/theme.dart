import 'package:flutter/material.dart';

import '../design_tokens/design_tokens.dart';

/// Light-mode color palette. Kept as an abstract final class so existing
/// `AppColors.foo` references continue to resolve without changes.
abstract final class AppColors {
  // Brand
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primarySoft = Color(0xFFEEF2FF);
  static const Color secondary = Color(0xFFEC4899);
  static const Color secondarySoft = Color(0xFFFDF2F8);
  static const Color accent = Color(0xFFEC4899);

  // Surfaces
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F5F9);
  static const Color cardBackground = Color(0xFFFFFFFF);

  // Status
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);

  // Text
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textLight = Color(0xFF94A3B8);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnPrimary70 = Color(0xB3FFFFFF);

  // Borders
  static const Color divider = Color(0xFFE2E8F0);
  static const Color border = Color(0xFFCBD5E1);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color cardBorder = Color(0xFFE2E8F0);

  // Neutrals (semantic ramp for grey replacements)
  static const Color neutral50 = Color(0xFFF8FAFC);
  static const Color neutral100 = Color(0xFFF1F5F9);
  static const Color neutral200 = Color(0xFFE2E8F0);
  static const Color neutral300 = Color(0xFFCBD5E1);
  static const Color neutral400 = Color(0xFF94A3B8);
  static const Color neutral500 = Color(0xFF64748B);
  static const Color neutral600 = Color(0xFF475569);
  static const Color neutral700 = Color(0xFF334155);
  static const Color neutral800 = Color(0xFF1E293B);
  static const Color neutral900 = Color(0xFF0F172A);

  // Misc
  static const Color iconDefault = Color(0xFF6366F1);
  static const Color iconSecondary = Color(0xFF64748B);
  static const Color shimmerBase = Color(0xFFE2E8F0);
  static const Color shimmerHighlight = Color(0xFFF8FAFC);
  static const Color online = Color(0xFF10B981);
  static const Color offline = Color(0xFF94A3B8);

  // Gradient helpers
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
  );
}

abstract final class AppColorsDark {
  static const Color primary = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF6366F1);
  static const Color secondary = Color(0xFFF472B6);
  static const Color accent = Color(0xFFF472B6);

  static const Color background = Color(0xFF0F172A);
  static const Color surface = Color(0xFF1E293B);
  static const Color surfaceLight = Color(0xFF334155);
  static const Color error = Color(0xFFF87171);
  static const Color success = Color(0xFF34D399);
  static const Color warning = Color(0xFFFBBF24);
  static const Color info = Color(0xFF60A5FA);

  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFFCBD5E1);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textLight = Color(0xFF64748B);

  static const Color divider = Color(0xFF334155);
  static const Color border = Color(0xFF475569);
  static const Color borderLight = Color(0xFF334155);
}

abstract final class AppTheme {
  static const Color primaryColor = AppColors.primary;

  static ThemeData get lightTheme => _buildTheme(brightness: Brightness.light);

  static ThemeData get darkTheme => _buildTheme(brightness: Brightness.dark);

  static ThemeData _buildTheme({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      primary: isDark ? AppColorsDark.primary : AppColors.primary,
      secondary: isDark ? AppColorsDark.secondary : AppColors.secondary,
      surface: isDark ? AppColorsDark.surface : AppColors.surface,
      error: isDark ? AppColorsDark.error : AppColors.error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: isDark ? AppColorsDark.textPrimary : AppColors.textPrimary,
      onError: Colors.white,
    );

    final Color textPrimary =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final Color textSecondary =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;
    final Color textMuted =
        isDark ? AppColorsDark.textMuted : AppColors.textMuted;
    final Color border = isDark ? AppColorsDark.border : AppColors.border;
    final Color divider = isDark ? AppColorsDark.divider : AppColors.divider;
    final Color surface = isDark ? AppColorsDark.surface : AppColors.surface;
    final Color background =
        isDark ? AppColorsDark.background : AppColors.background;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: surface,
      dividerColor: divider,
      splashFactory: InkRipple.splashFactory,
      // Keep AppBar in the brand primary so existing screens that draw
      // white-on-primary content (search TextField, custom titles, icons) stay
      // legible. Individual screens can override if they want a light header.
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColorsDark.surface : AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: AppTypography.h3.copyWith(color: Colors.white),
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.allLg,
          side: BorderSide(color: divider),
        ),
        surfaceTintColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          minimumSize: const Size(0, 48),
          textStyle: AppTypography.button,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.allMd),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          minimumSize: const Size(0, 48),
          textStyle: AppTypography.button,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.allMd),
          side: BorderSide(color: border),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          textStyle: AppTypography.button,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.allSm),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          minimumSize: const Size(0, 48),
          textStyle: AppTypography.button,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.allMd),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        hintStyle: AppTypography.body.copyWith(color: textMuted),
        labelStyle: AppTypography.label.copyWith(color: textSecondary),
        floatingLabelStyle: AppTypography.label.copyWith(color: scheme.primary),
        helperStyle: AppTypography.caption.copyWith(color: textMuted),
        errorStyle: AppTypography.caption.copyWith(color: scheme.error),
        border: OutlineInputBorder(
          borderRadius: AppRadius.allMd,
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.allMd,
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.allMd,
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.allMd,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.allMd,
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.allMd,
          borderSide: BorderSide(color: divider),
        ),
      ),
      dividerTheme: DividerThemeData(color: divider, thickness: 1, space: 1),
      chipTheme: ChipThemeData(
        backgroundColor: isDark
            ? AppColorsDark.surface
            : AppColors.neutral100,
        selectedColor: scheme.primary.withValues(alpha: 0.12),
        disabledColor: divider,
        labelStyle: AppTypography.label.copyWith(color: textPrimary),
        secondaryLabelStyle:
            AppTypography.label.copyWith(color: scheme.primary),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.allPill),
        side: BorderSide(color: divider),
        brightness: brightness,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: AppTypography.caption.copyWith(
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: AppTypography.caption,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.allXl),
        titleTextStyle: AppTypography.h3.copyWith(color: textPrimary),
        contentTextStyle: AppTypography.body.copyWith(color: textSecondary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColorsDark.surface : AppColors.neutral900,
        contentTextStyle: AppTypography.body.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.allMd),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: textMuted,
        labelStyle: AppTypography.button,
        unselectedLabelStyle: AppTypography.button,
        indicatorColor: scheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: divider,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.neutral900,
          borderRadius: AppRadius.allSm,
        ),
        textStyle: AppTypography.caption.copyWith(color: Colors.white),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: isDark
            ? AppColorsDark.surfaceLight
            : AppColors.neutral100,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return isDark ? AppColorsDark.textLight : Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return isDark ? AppColorsDark.border : AppColors.neutral300;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.allXs),
        side: BorderSide(color: border, width: 1.5),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        titleTextStyle:
            AppTypography.body.copyWith(color: textPrimary, fontWeight: FontWeight.w500),
        subtitleTextStyle: AppTypography.caption.copyWith(color: textMuted),
        iconColor: textSecondary,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.allMd),
      ),
      iconTheme: IconThemeData(color: textSecondary, size: 22),
      textTheme: TextTheme(
        headlineLarge: AppTypography.display.copyWith(color: textPrimary),
        headlineMedium: AppTypography.h1.copyWith(color: textPrimary),
        headlineSmall: AppTypography.h2.copyWith(color: textPrimary),
        titleLarge: AppTypography.h3.copyWith(color: textPrimary),
        titleMedium: AppTypography.h4.copyWith(color: textPrimary),
        titleSmall: AppTypography.label.copyWith(color: textPrimary),
        bodyLarge: AppTypography.bodyLg.copyWith(color: textPrimary),
        bodyMedium: AppTypography.body.copyWith(color: textSecondary),
        bodySmall: AppTypography.caption.copyWith(color: textMuted),
        labelLarge: AppTypography.button.copyWith(color: textPrimary),
        labelMedium: AppTypography.label.copyWith(color: textSecondary),
        labelSmall: AppTypography.overline.copyWith(color: textMuted),
      ),
    );
  }
}
