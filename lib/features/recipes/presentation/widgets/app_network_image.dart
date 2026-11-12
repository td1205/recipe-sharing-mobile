import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/config/api_config.dart';

class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.semanticLabel,
    this.fallbackIcon = Icons.restaurant_rounded,
  });

  final String? url;
  final BoxFit fit;
  final String? semanticLabel;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final validUrl = ImageUrl.resolve(url);
    if (validUrl.isEmpty) return _ImageFallback(fallbackIcon: fallbackIcon);
    return Image.network(
      validUrl,
      fit: fit,
      semanticLabel: semanticLabel,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return const ColoredBox(
          color: AppColors.limeSurface,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
      errorBuilder: (context, error, stackTrace) =>
          _ImageFallback(fallbackIcon: fallbackIcon),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.fallbackIcon});
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.limeSurface,
    child: Center(
      child: Icon(fallbackIcon, size: 40, color: AppColors.oliveSoft),
    ),
  );
}
