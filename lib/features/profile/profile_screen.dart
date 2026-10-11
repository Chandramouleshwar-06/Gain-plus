import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/exercise.dart';
import '../../models/profile.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/app_card.dart';
import '../../widgets/charts.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/ui.dart';
import '../plans/plans_screen.dart';
import '../account/account_card.dart';
import '../health/health_screen.dart';
import '../progress/achievements_view.dart';
import '../progress/progress_provider.dart';
import '../settings/settings_card.dart';
import 'goal_tile.dart';
import 'onboarding_screen.dart';
import 'profile_provider.dart';

/// Profile, weekly target, goals and body weight.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final progress = context.watch<ProgressProvider>();
    final p = profile.profile ?? const Profile();
    final thisWeek = progress.workoutsThisWeek(DateTime.now());

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            ScreenHeader(
              title: 'Profile',
              trailing: IconButton(
                tooltip: 'Edit profile',
                icon: const Icon(Icons.edit_outlined, color: AppColors.text),
                onPressed: () => _showEditProfile(context, p),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _IdentityCard(profile: p),
                  const SizedBox(height: 12),
                  const AccountCard(),
                  const SizedBox(height: 12),
                  const HealthLinkTile(),
                  const SizedBox(height: 12),
                  AppCard(
                    onTap: () => _showEditTarget(context, p),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Expanded(child: Text('WEEKLY TARGET', style: AppText.eyebrow)),
                            Text('$thisWeek / ${p.workoutsPerWeek}', style: AppText.display(24)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ProgressBar(value: thisWeek / p.workoutsPerWeek),
                        const SizedBox(height: 8),
                        Text(
                          thisWeek >= p.workoutsPerWeek
                              ? 'Target hit this week. Nice work.'
                              : '${p.workoutsPerWeek - thisWeek} more to hit your target this week.',
                          style: AppText.muted,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SectionHeader(title: 'Goals', actionLabel: 'Add', onAction: () => showAddGoalSheet(context)),
                  if (profile.goals.isEmpty)
                    AppCard(
                      onTap: () => showAddGoalSheet(context),
                      child: const Text('Set a lift or body weight goal to track it here.', style: AppText.muted),
                    )
                  else
                    AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Column(
                        children: [
                          for (var i = 0; i < profile.goals.length; i++) ...[
                            if (i > 0) const Divider(),
                            GoalTile(
                              goal: profile.goals[i],
                              onLongPress: () => _confirmDeleteGoal(context, profile.goals[i]),
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (profile.goals.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 6, left: 4),
                      child: Text('Long-press a goal to delete it.', style: TextStyle(fontSize: 12, color: AppColors.textFaint)),
                    ),
                  const SizedBox(height: 24),
                  SectionHeader(
                    title: 'Body weight',
                    actionLabel: 'Log',
                    onAction: () => showLogWeightDialog(context),
                  ),
                  _BodyWeightCard(entries: profile.bodyWeights),
                  const SizedBox(height: 24),
                  const SectionHeader(title: 'Achievements'),
                  const AchievementsGrid(),
                  const SizedBox(height: 24),
                  const SectionHeader(title: 'Settings'),
                  const SettingsCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteGoal(BuildContext context, Goal goal) async {
    final provider = context.read<ProfileProvider>();
    final ok = await confirmDialog(
      context,
      title: 'Delete goal?',
      message: 'This goal and its progress bar will be removed.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (ok) await provider.deleteGoal(goal.id);
  }

  void _showEditTarget(BuildContext context, Profile p) {
    var value = p.workoutsPerWeek;
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('WEEKLY TARGET', style: AppText.display(26)),
                const SizedBox(height: 16),
                WeeklyTargetPicker(value: value, onChanged: (v) => setSheetState(() => value = v)),
                const SizedBox(height: 16),
                PrimaryButton(
                  text: 'Save',
                  onPressed: () {
                    context.read<ProfileProvider>().saveProfile(p.copyWith(workoutsPerWeek: value));
                    Navigator.pop(sheetContext);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditProfile(BuildContext context, Profile p) {
    final name = TextEditingController(text: p.name);
    final height = TextEditingController(text: p.heightCm == null ? '' : formatWeight(p.heightCm!));
    var goal = p.primaryGoal;
    var experience = p.experience;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scroll) => ListView(
            controller: scroll,
            padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(sheetContext).bottom + 20),
            children: [
              Text('EDIT PROFILE', style: AppText.display(26)),
              const SizedBox(height: 16),
              TextField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: height,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                decoration: const InputDecoration(labelText: 'Height', suffixText: 'cm'),
              ),
              const SizedBox(height: 20),
              const Text('MAIN GOAL', style: AppText.eyebrow),
              const SizedBox(height: 8),
              for (final option in primaryGoalOptions)
                ChoiceCard(
                  option: option,
                  selected: goal == option.$1,
                  onTap: () => setSheetState(() => goal = option.$1),
                ),
              const SizedBox(height: 12),
              const Text('EXPERIENCE', style: AppText.eyebrow),
              const SizedBox(height: 8),
              for (final option in experienceOptions)
                ChoiceCard(
                  option: option,
                  selected: experience == option.$1,
                  onTap: () => setSheetState(() => experience = option.$1),
                ),
              const SizedBox(height: 12),
              PrimaryButton(
                text: 'Save',
                onPressed: () {
                  if (name.text.trim().isEmpty) return;
                  context.read<ProfileProvider>().saveProfile(p.copyWith(
                        name: name.text.trim(),
                        heightCm: double.tryParse(height.text.trim().replaceAll(',', '.')),
                        primaryGoal: goal,
                        experience: experience,
                      ));
                  Navigator.pop(sheetContext);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  final Profile profile;
  const _IdentityCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final initials = profile.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    String labelFor(List<ChoiceOption> options, String? value) =>
        options.where((o) => o.$1 == value).map((o) => o.$2).firstOrNull ?? '';
    final details = [
      labelFor(primaryGoalOptions, profile.primaryGoal),
      labelFor(experienceOptions, profile.experience),
    ].where((s) => s.isNotEmpty).join(' · ');

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.lime, shape: BoxShape.circle),
            child: Text(initials.isEmpty ? '?' : initials, style: AppText.display(26, color: AppColors.onLime)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.name.isEmpty ? 'ATHLETE' : profile.name.toUpperCase(), style: AppText.display(28)),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(details, style: AppText.muted),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BodyWeightCard extends StatelessWidget {
  final List<BodyWeightEntry> entries;
  const _BodyWeightCard({required this.entries});

  @override
  Widget build(BuildContext context) {
    final units = context.watch<ProfileProvider>().units;
    if (entries.isEmpty) {
      return AppCard(
        onTap: () => showLogWeightDialog(context),
        child: const Text('Log your weight to track it over time.', style: AppText.muted),
      );
    }

    final latest = entries.last;
    final change = latest.weightKg - entries.first.weightKg;
    final recent = entries.reversed.take(5).toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(units.number(latest.weightKg), style: AppText.display(44)),
              const SizedBox(width: 6),
              Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(units.label, style: AppText.muted)),
              const Spacer(),
              if (entries.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${change >= 0 ? '+' : '−'}${units.weight(change.abs())} since start',
                    style: AppText.muted,
                  ),
                ),
            ],
          ),
          if (entries.length >= 2) ...[
            const SizedBox(height: 12),
            TrendLineChart(
              points: [for (final e in entries) (e.date, units.fromKg(e.weightKg))],
              unit: units.label,
              semanticsLabel: 'Body weight over ${entries.length} weigh-ins, from '
                  '${units.weight(entries.first.weightKg)} to ${units.weight(latest.weightKg)}.',
            ),
          ],
          const SizedBox(height: 8),
          for (final entry in recent)
            Dismissible(
              key: ValueKey(entry.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 12),
                child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              ),
              onDismissed: (_) => context.read<ProfileProvider>().deleteBodyWeight(entry.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(DateFormat('EEE d MMM y').format(entry.date), style: AppText.muted)),
                    Text(units.weight(entry.weightKg), style: AppText.strong),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Asks for today's body weight and logs it.
Future<void> showLogWeightDialog(BuildContext context) async {
  final provider = context.read<ProfileProvider>();
  final text = await showDialog<String>(
    context: context,
    builder: (_) => TextPromptDialog(
      title: 'Log body weight',
      action: 'Save',
      initial: provider.latestBodyWeight == null ? '' : provider.units.number(provider.latestBodyWeight!),
      suffix: provider.units.label,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
    ),
  );
  final value = text == null ? null : double.tryParse(text.replaceAll(',', '.'));
  if (value == null || value <= 0) return;
  await provider.logBodyWeight(provider.units.toKg(value));
  if (!context.mounted) return;
  final achieved = await provider.markAchievedGoals(context.read<ProgressProvider>().prKgByExerciseId);
  if (achieved.isNotEmpty && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Goal reached! Nice work.")));
  }
}

/// Sheet for adding a lift or body weight goal.
void showAddGoalSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _AddGoalSheet(),
  );
}

class _AddGoalSheet extends StatefulWidget {
  const _AddGoalSheet();

  @override
  State<_AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends State<_AddGoalSheet> {
  String _type = Goal.typeLift;
  Exercise? _exercise;
  DateTime? _deadline;
  final _target = TextEditingController();
  final _currentWeight = TextEditingController();

  @override
  void dispose() {
    _target.dispose();
    _currentWeight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final latestWeight = context.watch<ProfileProvider>().latestBodyWeight;
    final units = context.watch<ProfileProvider>().units;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('NEW GOAL', style: AppText.display(26)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              for (final (type, label) in [(Goal.typeLift, 'Lift a weight'), (Goal.typeBodyWeight, 'Body weight')])
                ChoiceChip(
                  label: Text(label),
                  selected: _type == type,
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    color: _type == type ? AppColors.onLime : AppColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                  onSelected: (_) => setState(() => _type = type),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_type == Goal.typeLift)
            AppCard(
              color: AppColors.surfaceHigh,
              onTap: _pickExercise,
              child: Row(
                children: [
                  Expanded(
                    child: Text(_exercise?.name ?? 'Choose an exercise',
                        style: _exercise == null ? AppText.muted : AppText.strong),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                ],
              ),
            )
          else if (latestWeight == null) ...[
            TextField(
              controller: _currentWeight,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Current weight', suffixText: units.label),
            ),
          ] else
            Text('Current: ${units.weight(latestWeight)}', style: AppText.muted),
          const SizedBox(height: 12),
          TextField(
            controller: _target,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _type == Goal.typeLift ? 'Target weight to lift' : 'Target body weight',
              suffixText: units.label,
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            color: AppColors.surfaceHigh,
            onTap: _pickDeadline,
            child: Row(
              children: [
                const Icon(Icons.event_rounded, color: AppColors.textMuted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _deadline == null ? 'Add a deadline (optional)' : 'By ${DateFormat('d MMM y').format(_deadline!)}',
                    style: _deadline == null ? AppText.muted : AppText.strong,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton(text: 'Save goal', onPressed: _save),
        ],
      ),
    );
  }

  void _pickExercise() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scroll) => ExercisePicker(
          scrollController: scroll,
          onPick: (e) {
            setState(() => _exercise = e);
            Navigator.pop(sheetContext);
          },
        ),
      ),
    );
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      initialDate: _deadline ?? DateTime(now.year, now.month + 3, now.day),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final profile = context.read<ProfileProvider>();
    final prs = context.read<ProgressProvider>().prKgByExerciseId;

    final typed = double.tryParse(_target.text.trim().replaceAll(',', '.'));
    final target = typed == null ? null : profile.units.toKg(typed);
    if (target == null || target <= 0) {
      messenger.showSnackBar(const SnackBar(content: Text('Enter a target weight.')));
      return;
    }

    if (_type == Goal.typeLift) {
      if (_exercise == null) {
        messenger.showSnackBar(const SnackBar(content: Text('Choose an exercise.')));
        return;
      }
      await profile.addGoal(
        type: Goal.typeLift,
        exerciseId: _exercise!.id,
        targetValue: target,
        startValue: prs[_exercise!.id] ?? 0,
        deadline: _deadline,
      );
    } else {
      var current = profile.latestBodyWeight;
      if (current == null) {
        final typedCurrent = double.tryParse(_currentWeight.text.trim().replaceAll(',', '.'));
        current = typedCurrent == null ? null : profile.units.toKg(typedCurrent);
        if (current == null) {
          messenger.showSnackBar(const SnackBar(content: Text('Enter your current weight.')));
          return;
        }
        await profile.logBodyWeight(current);
      }
      await profile.addGoal(
        type: Goal.typeBodyWeight,
        targetValue: target,
        startValue: current,
        deadline: _deadline,
      );
    }
    navigator.pop();
  }
}
