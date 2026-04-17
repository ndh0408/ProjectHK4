import 'package:flutter/material.dart';

import '../../core/design_tokens/design_tokens.dart';
import 'app_button.dart';

/// Confirmation / informational dialog with a shared visual style.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.iconColor,
    this.primaryLabel = 'OK',
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.destructive = false,
    this.children,
  });

  final String title;
  final String? message;
  final IconData? icon;
  final Color? iconColor;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool destructive;
  final List<Widget>? children;

  static Future<bool?> confirm({
    required BuildContext context,
    required String title,
    String? message,
    String primaryLabel = 'Confirm',
    String? secondaryLabel = 'Cancel',
    IconData? icon,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: title,
        message: message,
        icon: icon,
        destructive: destructive,
        primaryLabel: primaryLabel,
        secondaryLabel: secondaryLabel,
        onPrimary: () => Navigator.of(ctx).pop(true),
        onSecondary: () => Navigator.of(ctx).pop(false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final effectiveIconColor =
        iconColor ?? (destructive ? colors.error : colors.primary);

    return Dialog(
      shape: AppRadius.dialogShape,
      child: Padding(
        padding: AppSpacing.dialogPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (icon != null) ...[
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: effectiveIconColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: effectiveIconColor, size: 28),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            Text(
              title,
              style: AppTypography.h3.copyWith(color: colors.onSurface),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                message!,
                style: AppTypography.body.copyWith(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (children != null) ...[
              const SizedBox(height: AppSpacing.md),
              ...children!,
            ],
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                if (secondaryLabel != null)
                  Expanded(
                    child: AppButton(
                      label: secondaryLabel!,
                      onPressed: onSecondary ?? () => Navigator.of(context).pop(false),
                      variant: AppButtonVariant.secondary,
                      expanded: true,
                    ),
                  ),
                if (secondaryLabel != null) const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppButton(
                    label: primaryLabel,
                    onPressed: onPrimary ?? () => Navigator.of(context).pop(true),
                    variant: destructive
                        ? AppButtonVariant.danger
                        : AppButtonVariant.primary,
                    expanded: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
