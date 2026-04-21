import 'package:flutter/material.dart';

import '../../core/config/theme.dart';
import '../../core/design_tokens/design_tokens.dart';

/// Reusable container matching the product's card style.
/// Combines surface, radius, border and optional tap handling.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.cardPadding,
    this.margin,
    this.onTap,
    this.borderColor,
    this.background,
    this.radius = AppRadius.lg,
    this.shadow = AppShadows.xs,
    this.border = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? background;
  final double radius;
  final List<BoxShadow>? shadow;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final bg = background ?? Theme.of(context).colorScheme.surface;
    final bc = borderColor ?? AppColors.divider;

    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        border: border ? Border.all(color: bc, width: 1) : null,
        boxShadow: shadow,
      ),
      child: child,
    );

    if (onTap == null) {
      return Container(margin: margin, child: content);
    }

    return Container(
      margin: margin,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: content,
        ),
      ),
    );
  }
}
