import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/config/theme.dart';
import '../../core/design_tokens/design_tokens.dart';
import 'app_button.dart';
import 'app_card.dart';

class EmptyState extends StatefulWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.iconColor,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;
  final bool compact;

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    unawaited(_controller.forward());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iconSize = widget.compact ? 48.0 : 80.0;
    final titleStyle = widget.compact
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.titleLarge;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.hasBoundedHeight
                      ? constraints.maxHeight
                      : 0,
                ),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal:
                          widget.compact ? AppSpacing.md : AppSpacing.lg,
                      vertical:
                          widget.compact ? AppSpacing.sm : AppSpacing.md,
                    ),
                    child: AppCard(
                      padding: EdgeInsets.all(
                          widget.compact ? AppSpacing.lg : AppSpacing.xl),
                      background: Theme.of(context).colorScheme.surface,
                      shadow: AppShadows.xs,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: iconSize * 1.5,
                            height: iconSize * 1.5,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  (widget.iconColor ?? AppColors.primary)
                                      .withValues(alpha: 0.14),
                                  (widget.iconColor ?? AppColors.primary)
                                      .withValues(alpha: 0.05),
                                ],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              widget.icon,
                              size: iconSize,
                              color: widget.iconColor ?? AppColors.primary,
                            ),
                          ),
                          SizedBox(
                              height: widget.compact
                                  ? AppSpacing.md
                                  : AppSpacing.lg),
                          Text(
                            widget.title,
                            style: titleStyle?.copyWith(
                                fontWeight: FontWeight.w700),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(
                              height: widget.compact
                                  ? AppSpacing.xs
                                  : AppSpacing.sm),
                          Text(
                            widget.subtitle,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                          if (widget.actionLabel != null &&
                              widget.onAction != null) ...[
                            SizedBox(
                                height: widget.compact
                                    ? AppSpacing.md
                                    : AppSpacing.lg),
                            AppButton(
                              label: widget.actionLabel!,
                              icon: Icons.explore_outlined,
                              onPressed: widget.onAction,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class LoadingState extends StatelessWidget {
  const LoadingState({
    super.key,
    this.message = 'Loading...',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxxl,
          vertical: AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: AppCard(
          padding: const EdgeInsets.all(AppSpacing.xxxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  size: 40,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Something went wrong',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Try again',
                  variant: AppButtonVariant.secondary,
                  icon: Icons.refresh_rounded,
                  onPressed: onRetry,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
