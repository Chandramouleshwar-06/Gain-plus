import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum ButtonVariant {
  /// Lime fill, dark text. The main action on a screen.
  primary,

  /// Near-black fill, lime text. For use on a lime card.
  inverse,

  /// Dark surface with a subtle border.
  secondary,
}

/// Full-width pill button.
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLarge;
  final IconData? icon;
  final ButtonVariant variant;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLarge = false,
    this.icon,
    this.variant = ButtonVariant.primary,
  });

  @override
  Widget build(BuildContext context) {
    final (background, foreground, side) = switch (variant) {
      ButtonVariant.primary => (AppColors.lime, AppColors.onLime, BorderSide.none),
      ButtonVariant.inverse => (AppColors.onLime, AppColors.lime, BorderSide.none),
      ButtonVariant.secondary => (AppColors.navBar, AppColors.text, const BorderSide(color: AppColors.border)),
    };

    final label = Text(
      variant == ButtonVariant.secondary ? text : text.toUpperCase(),
      style: variant == ButtonVariant.secondary
          ? const TextStyle(fontFamily: AppFonts.body, fontSize: 15, fontWeight: FontWeight.w600)
          : AppText.display(isLarge ? 20 : 18, color: foreground, weight: FontWeight.w700)
              .copyWith(letterSpacing: 1.0),
    );

    return SizedBox(
      width: double.infinity,
      height: isLarge ? 54 : 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: AppColors.surfaceHigh,
          disabledForegroundColor: AppColors.textFaint,
          side: side,
          shape: const StadiumBorder(),
          elevation: 0,
        ),
        // Scales the label down rather than overflowing on narrow screens or
        // with large system text.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: icon == null
              ? label
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [Icon(icon, size: 20), const SizedBox(width: 8), label],
                ),
        ),
      ),
    );
  }
}
