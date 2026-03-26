import 'package:flutter/material.dart';

import '../../core/config/theme.dart';
import '../models/boost.dart';

/// A badge widget that displays when an event is boosted
class BoostBadge extends StatelessWidget {
  const BoostBadge({
    super.key,
    this.package,
    this.size = BoostBadgeSize.small,
    this.showLabel = true,
  });

  final BoostPackage? package;
  final BoostBadgeSize size;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final config = _getConfig();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size == BoostBadgeSize.small ? 6 : 10,
        vertical: size == BoostBadgeSize.small ? 3 : 5,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: config.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size == BoostBadgeSize.small ? 10 : 16),
        boxShadow: [
          BoxShadow(
            color: config.gradientColors.first.withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            config.icon,
            size: size == BoostBadgeSize.small ? 10 : 14,
            color: Colors.white,
          ),
          if (showLabel) ...[
            SizedBox(width: size == BoostBadgeSize.small ? 3 : 4),
            Text(
              config.label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: size == BoostBadgeSize.small ? 9 : 11,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  _BoostBadgeConfig _getConfig() {
    switch (package) {
      case BoostPackage.vip:
        return _BoostBadgeConfig(
          label: 'VIP',
          icon: Icons.diamond_rounded,
          gradientColors: [
            const Color(0xFFFFD700),
            const Color(0xFFFFA500),
          ],
          multiplier: '5x',
        );
      case BoostPackage.premium:
        return _BoostBadgeConfig(
          label: 'PREMIUM',
          icon: Icons.workspace_premium_rounded,
          gradientColors: [
            const Color(0xFF9333EA),
            const Color(0xFFDB2777),
          ],
          multiplier: '3x',
        );
      case BoostPackage.standard:
        return _BoostBadgeConfig(
          label: 'FEATURED',
          icon: Icons.star_rounded,
          gradientColors: [
            AppColors.primary,
            AppColors.secondary,
          ],
          multiplier: '2x',
        );
      case BoostPackage.basic:
      default:
        return _BoostBadgeConfig(
          label: 'BOOSTED',
          icon: Icons.rocket_launch_rounded,
          gradientColors: [
            const Color(0xFF3B82F6),
            const Color(0xFF60A5FA),
          ],
          multiplier: '1.5x',
        );
    }
  }
}

class _BoostBadgeConfig {
  final String label;
  final IconData icon;
  final List<Color> gradientColors;
  final String multiplier;

  const _BoostBadgeConfig({
    required this.label,
    required this.icon,
    required this.gradientColors,
    required this.multiplier,
  });
}

enum BoostBadgeSize {
  small,
  medium,
}

/// A simple "Featured" badge for boosted events
class FeaturedBadge extends StatelessWidget {
  const FeaturedBadge({
    super.key,
    this.size = BoostBadgeSize.small,
  });

  final BoostBadgeSize size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size == BoostBadgeSize.small ? 6 : 10,
        vertical: size == BoostBadgeSize.small ? 3 : 5,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size == BoostBadgeSize.small ? 10 : 16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            size: size == BoostBadgeSize.small ? 10 : 14,
            color: Colors.white,
          ),
          SizedBox(width: size == BoostBadgeSize.small ? 3 : 4),
          Text(
            'FEATURED',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: size == BoostBadgeSize.small ? 9 : 11,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// A banner-style boost indicator for home page featured events
class BoostBanner extends StatelessWidget {
  const BoostBanner({
    super.key,
    this.package,
  });

  final BoostPackage? package;

  @override
  Widget build(BuildContext context) {
    final config = _getConfig();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: config.gradientColors,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            config.icon,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            config.label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              config.multiplier,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _BoostBannerConfig _getConfig() {
    switch (package) {
      case BoostPackage.vip:
        return _BoostBannerConfig(
          label: 'VIP EVENT',
          icon: Icons.diamond_rounded,
          gradientColors: [const Color(0xFFFFD700), const Color(0xFFFFA500)],
          multiplier: '5x BOOST',
        );
      case BoostPackage.premium:
        return _BoostBannerConfig(
          label: 'PREMIUM EVENT',
          icon: Icons.workspace_premium_rounded,
          gradientColors: [const Color(0xFF9333EA), const Color(0xFFDB2777)],
          multiplier: '3x BOOST',
        );
      case BoostPackage.standard:
        return _BoostBannerConfig(
          label: 'FEATURED EVENT',
          icon: Icons.star_rounded,
          gradientColors: [AppColors.primary, AppColors.secondary],
          multiplier: '2x BOOST',
        );
      case BoostPackage.basic:
      default:
        return _BoostBannerConfig(
          label: 'BOOSTED EVENT',
          icon: Icons.rocket_launch_rounded,
          gradientColors: [const Color(0xFF3B82F6), const Color(0xFF60A5FA)],
          multiplier: '1.5x BOOST',
        );
    }
  }
}

class _BoostBannerConfig {
  final String label;
  final IconData icon;
  final List<Color> gradientColors;
  final String multiplier;

  const _BoostBannerConfig({
    required this.label,
    required this.icon,
    required this.gradientColors,
    required this.multiplier,
  });
}
