import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/ui.dart';
import '../profile/profile_provider.dart';
import 'achievement_tracker.dart';
import 'insights.dart';
import 'progress_provider.dart';

/// Badge grid: unlocked badges in lime, locked ones with a progress ring.
class AchievementsGrid extends StatelessWidget {
  const AchievementsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = achievementStats(context.watch<ProgressProvider>(), context.watch<ProfileProvider>());
    final unlocked = achievements.where((a) => a.isUnlocked(stats)).length;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('$unlocked of ${achievements.length} unlocked', style: AppText.muted),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 8,
            childAspectRatio: 0.72,
            children: [
              for (final a in achievements) _Badge(achievement: a, stats: stats),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final Achievement achievement;
  final AchievementStats stats;

  const _Badge({required this.achievement, required this.stats});

  @override
  Widget build(BuildContext context) {
    final done = achievement.isUnlocked(stats);
    final progress = achievement.progress(stats);

    return Semantics(
      button: true,
      label: '${achievement.title}, ${done ? 'unlocked' : '${(progress * 100).round()} percent'}',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetails(context, done, progress),
        child: Column(
          children: [
            SizedBox(
              width: 58,
              height: 58,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (!done)
                    SizedBox(
                      width: 58,
                      height: 58,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 3,
                        color: AppColors.lime,
                        backgroundColor: AppColors.surfaceHigh,
                      ),
                    ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done ? AppColors.lime : AppColors.surfaceHigh,
                    ),
                    child: Icon(achievement.icon, color: done ? AppColors.onLime : AppColors.textFaint, size: 24),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              achievement.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: done ? AppColors.text : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, bool done, double progress) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(achievement.icon, color: done ? AppColors.lime : AppColors.textMuted, size: 40),
        title: Text(achievement.title.toUpperCase(), textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(achievement.description, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            if (done)
              const Text('Unlocked', style: TextStyle(color: AppColors.lime, fontWeight: FontWeight.w700))
            else ...[
              ProgressBar(value: progress),
              const SizedBox(height: 6),
              Text('${(progress * 100).round()}% there', style: AppText.muted),
            ],
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('OK'))],
      ),
    );
  }
}

/// Celebrates newly unlocked achievements.
Future<void> showAchievementsUnlocked(BuildContext context, List<Achievement> unlocked) {
  final first = unlocked.first;
  final others = unlocked.length - 1;
  return showDialog(
    context: context,
    builder: (dialogContext) => Dialog(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(color: AppColors.lime, shape: BoxShape.circle),
              child: Icon(first.icon, color: AppColors.onLime, size: 48),
            ),
            const SizedBox(height: 16),
            Text('ACHIEVEMENT UNLOCKED', style: AppText.eyebrow.copyWith(color: AppColors.lime)),
            const SizedBox(height: 6),
            Text(first.title.toUpperCase(), textAlign: TextAlign.center, style: AppText.display(32)),
            const SizedBox(height: 6),
            Text(first.description, textAlign: TextAlign.center, style: AppText.muted),
            if (others > 0) ...[
              const SizedBox(height: 8),
              Text('+ $others more in your profile', style: AppText.muted),
            ],
            const SizedBox(height: 20),
            PrimaryButton(text: 'Nice', onPressed: () => Navigator.pop(dialogContext)),
          ],
        ),
      ),
    ),
  );
}
