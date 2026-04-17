import 'package:flutter/material.dart';

import '../../core/design_tokens/design_tokens.dart';

enum AppButtonVariant { primary, secondary, ghost, danger }

enum AppButtonSize { sm, md, lg }

/// Unified button with variant, size and built-in loading state.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.icon,
    this.trailing,
    this.loading = false,
    this.expanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final Widget? trailing;
  final bool loading;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final disabled = onPressed == null || loading;

    final (bg, fg, borderColor) = switch (variant) {
      AppButtonVariant.primary => (colors.primary, Colors.white, colors.primary),
      AppButtonVariant.secondary => (colors.surface, colors.onSurface, colors.outline),
      AppButtonVariant.ghost => (Colors.transparent, colors.primary, Colors.transparent),
      AppButtonVariant.danger => (colors.error, Colors.white, colors.error),
    };

    final (vPad, hPad, fontSize, minHeight) = switch (size) {
      AppButtonSize.sm => (AppSpacing.sm, AppSpacing.md, 13.0, 36.0),
      AppButtonSize.md => (AppSpacing.md, AppSpacing.xl, 14.0, 48.0),
      AppButtonSize.lg => (AppSpacing.lg, AppSpacing.xxl, 15.0, 56.0),
    };

    final effectiveBg = disabled ? bg.withValues(alpha: 0.5) : bg;
    final effectiveFg = disabled ? fg.withValues(alpha: 0.5) : fg;

    final button = Material(
      color: effectiveBg,
      borderRadius: AppRadius.allMd,
      child: InkWell(
        onTap: loading ? null : onPressed,
        borderRadius: AppRadius.allMd,
        child: Container(
          constraints: BoxConstraints(minHeight: minHeight),
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          decoration: BoxDecoration(
            borderRadius: AppRadius.allMd,
            border: variant == AppButtonVariant.secondary
                ? Border.all(color: borderColor)
                : null,
          ),
          child: Row(
            mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(effectiveFg),
                  ),
                )
              else if (icon != null)
                Icon(icon, size: 18, color: effectiveFg),
              if ((loading || icon != null)) const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.button.copyWith(
                    color: effectiveFg,
                    fontSize: fontSize,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );

    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}
