import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The official KanjiKi (漢字気) brand logo widget.
///
/// Features the custom Dark Neobrutalism squircle badge with the
/// Japanese "気" (Ki / energy) calligraphy and radiant SRS energy spark.
class KanjiKiLogo extends StatelessWidget {
  final double size;
  final double? borderRadius;
  final bool showShadow;
  final VoidCallback? onTap;

  const KanjiKiLogo({
    super.key,
    this.size = 48,
    this.borderRadius,
    this.showShadow = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double radius = borderRadius ?? (size * 0.22);
    final shadowOffset = (size * 0.05).clamp(1.5, 4.0);

    Widget logoImage = Image.asset(
      'assets/icons/kanjiki_icon.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) {
        // Fallback for headless testing or missing bundle
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: AppColors.primaryLight, width: 2),
          ),
          child: Center(
            child: Text(
              '気',
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );

    if (showShadow) {
      logoImage = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              offset: Offset(shadowOffset, shadowOffset),
              blurRadius: 0,
            ),
          ],
        ),
        child: logoImage,
      );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: logoImage,
      );
    }

    return logoImage;
  }
}
