import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Big condensed screen title with an optional eyebrow and trailing widget.
class ScreenHeader extends StatelessWidget {
  final String title;
  final String? eyebrow;
  final Widget? trailing;

  const ScreenHeader({super.key, required this.title, this.eyebrow, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) ...[
                  Text(eyebrow!.toUpperCase(), style: AppText.eyebrow),
                  const SizedBox(height: 4),
                ],
                Text(title.toUpperCase(), style: AppText.display(34)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Section title row, e.g. "GOALS ........ See all".
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title.toUpperCase(),
                style: AppText.display(22, weight: FontWeight.w700).copyWith(letterSpacing: 0.8)),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

/// Small stat card: icon, big number, caption.
class StatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const StatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor = AppColors.lime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: AppText.display(30)),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// Rounded progress bar. [value] is clamped to 0..1.
class ProgressBar extends StatelessWidget {
  final double value;
  final double height;
  final Color color;
  final Color trackColor;

  const ProgressBar({
    super.key,
    required this.value,
    this.height = 8,
    this.color = AppColors.lime,
    this.trackColor = AppColors.border,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        color: color,
        backgroundColor: trackColor,
      ),
    );
  }
}

/// Small rounded label, e.g. "6 exercises".
class InfoChip extends StatelessWidget {
  final String text;
  final Color background;
  final Color foreground;

  const InfoChip(
    this.text, {
    super.key,
    this.background = AppColors.surfaceHigh,
    this.foreground = AppColors.textMuted,
  });

  /// Chip for use on a lime card.
  const InfoChip.onLime(this.text, {super.key})
      : background = const Color(0x1F0B0B0C),
        foreground = AppColors.onLime;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: foreground)),
    );
  }
}

/// Centered icon + title + message, with an optional action button.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
              child: Icon(icon, size: 34, color: AppColors.lime),
            ),
            const SizedBox(height: 16),
            Text(title.toUpperCase(), style: AppText.display(24, weight: FontWeight.w700), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(message, style: AppText.muted, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// Shows a confirm dialog and returns true if the user confirmed.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
          child: Text(cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: destructive ? TextButton.styleFrom(foregroundColor: AppColors.danger) : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
