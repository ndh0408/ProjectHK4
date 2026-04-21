import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/config/theme.dart';

class AvatarComponent extends StatelessWidget {
  const AvatarComponent({
    super.key,
    this.url,
    this.initials = '?',
    this.size = 40,
    this.backgroundColor,
  });

  final String? url;
  final String initials;
  final double size;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: backgroundColor ?? AppColors.primarySoft,
      backgroundImage: url != null ? CachedNetworkImageProvider(url!) : null,
      child: url == null
          ? Text(
              initials.isNotEmpty ? initials[0].toUpperCase() : '?',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.4,
              ),
            )
          : null,
    );
  }
}
