import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/food.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/ui.dart';
import '../profile/profile_provider.dart';
import 'food_search_screen.dart';
import 'nutrition_provider.dart';
import 'targets.dart';

/// Today's targets for the profile, or null if details are missing.
NutritionTargets? targetsFor(ProfileProvider profile) {
  final p = profile.profile;
  return calculateTargets(
    weightKg: profile.latestBodyWeight,
    heightCm: p?.heightCm,
    birthYear: p?.birthYear,
    sex: p?.sex,
    activityLevel: p?.activityLevel,
    goal: p?.primaryGoal,
    currentYear: DateTime.now().year,
  );
}

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<NutritionProvider>().load());
  }

  @override
  Widget build(BuildContext context) {
    final nutrition = context.watch<NutritionProvider>();
    final targets = targetsFor(context.watch<ProfileProvider>());
    final day = nutrition.day;

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Row(
            children: [
              Expanded(child: Text('NUTRITION', style: AppText.display(36))),
              IconButton(
                tooltip: 'Previous day',
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => nutrition.setDay(day.subtract(const Duration(days: 1))),
              ),
              Text(nutrition.isToday ? 'Today' : DateFormat('EEE d MMM').format(day), style: AppText.strong),
              IconButton(
                tooltip: 'Next day',
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: nutrition.isToday ? null : () => nutrition.setDay(day.add(const Duration(days: 1))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (targets == null) const _SetUpTargetsCard() else _Summary(totals: nutrition.totals, targets: targets),
          const SizedBox(height: 20),
          for (final meal in meals) _MealSection(meal: meal),
          const SizedBox(height: 8),
          const Text(
            'Built-in foods use typical home portions; values are approximate. '
            'Packaged foods come from Open Food Facts.',
            style: TextStyle(fontSize: 12, color: AppColors.textFaint),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final Macros totals;
  final NutritionTargets targets;
  const _Summary({required this.totals, required this.targets});

  @override
  Widget build(BuildContext context) {
    final left = targets.kcal - totals.kcal;
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatWeight(left.abs().roundToDouble()),
                  style: AppText.display(48, color: left >= 0 ? AppColors.text : AppColors.orange)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(left >= 0 ? 'kcal left' : 'kcal over', style: AppText.muted),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('${totals.kcal.round()} / ${targets.kcal.round()}', style: AppText.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ProgressBar(value: totals.kcal / targets.kcal, color: left >= 0 ? AppColors.lime : AppColors.orange),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _MacroBar(label: 'Protein', value: totals.protein, target: targets.protein)),
              const SizedBox(width: 12),
              Expanded(child: _MacroBar(label: 'Carbs', value: totals.carbs, target: targets.carbs)),
              const SizedBox(width: 12),
              Expanded(child: _MacroBar(label: 'Fat', value: totals.fat, target: targets.fat)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroBar extends StatelessWidget {
  final String label;
  final double value;
  final double target;
  const _MacroBar({required this.label, required this.value, required this.target});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppText.eyebrow),
        const SizedBox(height: 4),
        Text('${value.round()} / ${target.round()} g', style: AppText.strong, maxLines: 1, overflow: TextOverflow.fade),
        const SizedBox(height: 6),
        ProgressBar(value: target == 0 ? 0 : value / target, height: 6),
      ],
    );
  }
}

class _SetUpTargetsCard extends StatelessWidget {
  const _SetUpTargetsCard();

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final missing = missingForTargets(
      weightKg: profile.latestBodyWeight,
      heightCm: profile.profile?.heightCm,
      birthYear: profile.profile?.birthYear,
      sex: profile.profile?.sex,
      activityLevel: profile.profile?.activityLevel,
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('SET UP YOUR TARGETS', style: AppText.eyebrow),
          const SizedBox(height: 6),
          Text('Daily calorie and protein targets need your ${missing.join(', ')}.', style: AppText.muted),
          const SizedBox(height: 12),
          PrimaryButton(text: 'Add details', onPressed: () => showTargetsSetup(context)),
        ],
      ),
    );
  }
}

class _MealSection extends StatelessWidget {
  final String meal;
  const _MealSection({required this.meal});

  @override
  Widget build(BuildContext context) {
    final nutrition = context.watch<NutritionProvider>();
    final entries = nutrition.logs.where((l) => l.meal == meal).toList();
    final total = nutrition.totalsFor(meal);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(mealLabel(meal).toUpperCase(), style: AppText.display(20, weight: FontWeight.w700))),
                if (entries.isNotEmpty)
                  Text('${total.kcal.round()} kcal · ${total.protein.round()} g protein', style: AppText.muted),
                IconButton(
                  tooltip: 'Add to ${mealLabel(meal)}',
                  icon: const Icon(Icons.add_circle_rounded, color: AppColors.lime),
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => FoodSearchScreen(meal: meal))),
                ),
              ],
            ),
            for (final entry in entries)
              Dismissible(
                key: ValueKey(entry.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                ),
                onDismissed: (_) => nutrition.deleteLog(entry.id),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 6, 8, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.name, style: AppText.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text('${formatWeight(entry.servings)} × serving · ${entry.protein.round()} g protein',
                                style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                      Text('${entry.kcal.round()}', style: AppText.strong),
                    ],
                  ),
                ),
              ),
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text('Nothing logged', style: TextStyle(fontSize: 13, color: AppColors.textFaint)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Asks for whatever's missing for targets: sex, activity, height, birth
/// year, body weight.
Future<void> showTargetsSetup(BuildContext context) {
  return showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => const _TargetsSetupSheet());
}

class _TargetsSetupSheet extends StatefulWidget {
  const _TargetsSetupSheet();

  @override
  State<_TargetsSetupSheet> createState() => _TargetsSetupSheetState();
}

class _TargetsSetupSheetState extends State<_TargetsSetupSheet> {
  late String? _sex = context.read<ProfileProvider>().profile?.sex;
  late String? _activity = context.read<ProfileProvider>().profile?.activityLevel;
  late final _height = TextEditingController(
      text: context.read<ProfileProvider>().profile?.heightCm == null
          ? ''
          : formatWeight(context.read<ProfileProvider>().profile!.heightCm!));
  late final _birthYear =
      TextEditingController(text: context.read<ProfileProvider>().profile?.birthYear?.toString() ?? '');
  final _weight = TextEditingController();

  @override
  void dispose() {
    _height.dispose();
    _birthYear.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final profileProvider = context.read<ProfileProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final height = double.tryParse(_height.text.replaceAll(',', '.'));
    final year = int.tryParse(_birthYear.text);
    final typedWeight = double.tryParse(_weight.text.replaceAll(',', '.'));
    if (_sex == null || _activity == null || height == null || year == null ||
        (profileProvider.latestBodyWeight == null && typedWeight == null)) {
      messenger.showSnackBar(const SnackBar(content: Text('Fill in every field.')));
      return;
    }
    if (typedWeight != null) await profileProvider.logBodyWeight(profileProvider.units.toKg(typedWeight));
    final p = profileProvider.profile;
    if (p != null) {
      await profileProvider.saveProfile(p.copyWith(sex: _sex, activityLevel: _activity, heightCm: height, birthYear: year));
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    Widget choice(String label, bool selected, VoidCallback onTap) => ChoiceChip(
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          labelStyle: TextStyle(color: selected ? AppColors.onLime : AppColors.text, fontWeight: FontWeight.w700),
          onSelected: (_) => onTap(),
        );

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('YOUR TARGETS', style: AppText.display(26)),
            const SizedBox(height: 4),
            const Text('Used to work out your daily calories and protein. Stays on your account.',
                style: AppText.muted),
            const SizedBox(height: 16),
            const Text('SEX', style: AppText.eyebrow),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              choice('Male', _sex == 'male', () => setState(() => _sex = 'male')),
              choice('Female', _sex == 'female', () => setState(() => _sex = 'female')),
            ]),
            const SizedBox(height: 16),
            const Text('ACTIVITY', style: AppText.eyebrow),
            const SizedBox(height: 6),
            RadioGroup<String>(
              groupValue: _activity,
              onChanged: (v) => setState(() => _activity = v),
              child: Column(
                children: [
                  for (final (code, label, description, _) in activityLevels)
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: code,
                      activeColor: AppColors.lime,
                      title: Text(label, style: AppText.strong),
                      subtitle: Text(description, style: AppText.muted),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _height,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    decoration: const InputDecoration(labelText: 'Height', suffixText: 'cm'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _birthYear,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                    decoration: const InputDecoration(labelText: 'Year of birth'),
                  ),
                ),
              ],
            ),
            if (profile.latestBodyWeight == null) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _weight,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Body weight', suffixText: profile.units.label),
              ),
            ],
            const SizedBox(height: 20),
            PrimaryButton(text: 'Save', onPressed: _save),
          ],
        ),
      ),
    );
  }
}
