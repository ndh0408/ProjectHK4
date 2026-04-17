import 'package:flutter/material.dart';

import '../../core/config/theme.dart';
import '../../core/design_tokens/design_tokens.dart';

/// Simple shimmering box for loading placeholders. Used by SkeletonList and
/// custom skeleton compositions. No external shimmer dep.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    this.height = 12,
    this.radius = AppRadius.sm,
  });

  final double width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            color: Color.lerp(
              AppColors.shimmerBase,
              AppColors.shimmerHighlight,
              _controller.value,
            ),
          ),
        );
      },
    );
  }
}

class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 84,
    this.hasLeading = true,
    this.padding,
  });

  final int itemCount;
  final double itemHeight;
  final bool hasLeading;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, __) => Container(
        height: itemHeight,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: AppRadius.allLg,
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            if (hasLeading) ...[
              SkeletonBox(width: 56, height: 56, radius: AppRadius.md),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  SkeletonBox(height: 14, width: 180),
                  SizedBox(height: AppSpacing.sm),
                  SkeletonBox(height: 10, width: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
