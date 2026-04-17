import 'package:flutter/material.dart';

import '../../core/config/theme.dart';
import '../../core/design_tokens/design_tokens.dart';

enum StatusChipVariant { success, warning, danger, info, primary, neutral }

/// Small pill that conveys status with color + icon + text.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.variant = StatusChipVariant.neutral,
    this.icon,
    this.compact = false,
  });

  final String label;
  final StatusChipVariant variant;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (variant) {
      StatusChipVariant.success => (AppColors.successLight, AppColors.success),
      StatusChipVariant.warning => (AppColors.warningLight, AppColors.warning),
      StatusChipVariant.danger => (AppColors.errorLight, AppColors.error),
      StatusChipVariant.info => (AppColors.infoLight, AppColors.info),
      StatusChipVariant.primary => (AppColors.primarySoft, AppColors.primary),
      StatusChipVariant.neutral => (AppColors.neutral100, AppColors.neutral700),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.sm : AppSpacing.md,
        vertical: compact ? 2 : AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.allPill,
        border: Border.all(color: fg.withValues(alpha: 0.22), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 12 : 14, color: fg),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
              fontSize: compact ? 10.5 : 11.5,
            ),
          ),
        ],
      ),
    );
  }
}
