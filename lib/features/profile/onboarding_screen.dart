import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/profile.dart';
import '../../theme/app_theme.dart';
import '../../utils/units.dart';
import '../../widgets/primary_button.dart';
import 'profile_provider.dart';

/// Option shown as a selectable card: value, label, description, icon.
typedef ChoiceOption = (String, String, String, IconData);

const primaryGoalOptions = <ChoiceOption>[
  ('build_muscle', 'Build muscle', 'Get bigger and more defined', Icons.fitness_center_rounded),
  ('get_stronger', 'Get stronger', 'Lift heavier on the big lifts', Icons.trending_up_rounded),
  ('lose_fat', 'Lose fat', 'Drop weight, keep the muscle', Icons.local_fire_department_rounded),
  ('general_fitness', 'General fitness', 'Feel good and stay consistent', Icons.favorite_rounded),
];

const experienceOptions = <ChoiceOption>[
  ('beginner', 'Beginner', 'Less than a year of training', Icons.looks_one_rounded),
  ('intermediate', 'Intermediate', '1 to 3 years', Icons.looks_two_rounded),
  ('advanced', 'Advanced', 'More than 3 years', Icons.looks_3_rounded),
];

/// First-launch questions: name, goal, training frequency and body stats.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _pageCount = 4;
  final _pages = PageController();
  final _name = TextEditingController();
  final _weight = TextEditingController();
  final _height = TextEditingController();
  final _birthYear = TextEditingController();

  int _page = 0;
  String? _goal;
  String _experience = 'beginner';
  int _perWeek = 3;
  Units _units = const Units.kg();
  bool _saving = false;

  @override
  void dispose() {
    _pages.dispose();
    _name.dispose();
    _weight.dispose();
    _height.dispose();
    _birthYear.dispose();
    super.dispose();
  }

  bool get _canContinue => switch (_page) {
        0 => _name.text.trim().isNotEmpty,
        1 => _goal != null,
        _ => true,
      };

  void _next() {
    FocusScope.of(context).unfocus();
    if (_page < _pageCount - 1) {
      _pages.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    double? parse(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));
    await context.read<ProfileProvider>().completeOnboarding(
          Profile(
            name: _name.text.trim(),
            primaryGoal: _goal,
            experience: _experience,
            workoutsPerWeek: _perWeek,
            heightCm: parse(_height),
            birthYear: int.tryParse(_birthYear.text.trim()),
            onboardedAt: DateTime.now(),
            units: _units.code,
          ),
          bodyWeightKg: parse(_weight) == null ? null : _units.toKg(parse(_weight)!),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: _page == 0
                        ? null
                        : () => _pages.previousPage(
                            duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic),
                    icon: Icon(Icons.arrow_back_rounded, color: _page == 0 ? Colors.transparent : AppColors.text),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        for (var i = 0; i < _pageCount; i++)
                          Expanded(
                            child: Container(
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: i <= _page ? AppColors.lime : AppColors.surfaceHigh,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (p) => setState(() => _page = p),
                children: [
                  _Step(
                    eyebrow: 'WELCOME TO GAIN+',
                    title: "WHAT'S YOUR NAME?",
                    children: [
                      TextField(
                        controller: _name,
                        autofocus: true,
                        textCapitalization: TextCapitalization.words,
                        style: AppText.display(28, weight: FontWeight.w700),
                        decoration: const InputDecoration(hintText: 'Your name'),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _canContinue ? _next() : null,
                      ),
                    ],
                  ),
                  _Step(
                    eyebrow: 'STEP 2 OF 4',
                    title: "WHAT'S YOUR MAIN GOAL?",
                    children: [
                      for (final option in primaryGoalOptions)
                        ChoiceCard(
                          option: option,
                          selected: _goal == option.$1,
                          onTap: () => setState(() => _goal = option.$1),
                        ),
                    ],
                  ),
                  _Step(
                    eyebrow: 'STEP 3 OF 4',
                    title: 'HOW OFTEN WILL YOU TRAIN?',
                    children: [
                      WeeklyTargetPicker(value: _perWeek, onChanged: (v) => setState(() => _perWeek = v)),
                      const SizedBox(height: 24),
                      const Text('EXPERIENCE', style: AppText.eyebrow),
                      const SizedBox(height: 8),
                      for (final option in experienceOptions)
                        ChoiceCard(
                          option: option,
                          selected: _experience == option.$1,
                          onTap: () => setState(() => _experience = option.$1),
                        ),
                    ],
                  ),
                  _Step(
                    eyebrow: 'STEP 4 OF 4 · OPTIONAL',
                    title: 'ABOUT YOU',
                    subtitle: 'Used for body weight goals. You can skip this and add it later.',
                    children: [
                      Row(
                        children: [
                          const Expanded(child: Text('UNITS', style: AppText.eyebrow)),
                          SegmentedButton<bool>(
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment(value: false, label: Text('kg')),
                              ButtonSegment(value: true, label: Text('lb')),
                            ],
                            selected: {_units.isLb},
                            onSelectionChanged: (s) =>
                                setState(() => _units = s.first ? const Units.lb() : const Units.kg()),
                            style: SegmentedButton.styleFrom(
                              selectedBackgroundColor: AppColors.lime,
                              selectedForegroundColor: AppColors.onLime,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _NumberInput(controller: _weight, label: 'Body weight', suffix: _units.label, decimal: true),
                      const SizedBox(height: 12),
                      _NumberInput(controller: _height, label: 'Height', suffix: 'cm'),
                      const SizedBox(height: 12),
                      _NumberInput(controller: _birthYear, label: 'Year of birth', maxLength: 4),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: PrimaryButton(
                text: _page == _pageCount - 1 ? "Let's go" : 'Continue',
                isLarge: true,
                onPressed: _canContinue && !_saving ? _next : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const _Step({required this.eyebrow, required this.title, this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      children: [
        Text(eyebrow, style: AppText.eyebrow.copyWith(color: AppColors.lime)),
        const SizedBox(height: 8),
        Text(title, style: AppText.display(40)),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(subtitle!, style: AppText.muted),
        ],
        const SizedBox(height: 24),
        ...children,
      ],
    );
  }
}

/// Selectable option card with an icon, label and description.
class ChoiceCard extends StatelessWidget {
  final ChoiceOption option;
  final bool selected;
  final VoidCallback onTap;

  const ChoiceCard({super.key, required this.option, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (_, label, description, icon) = option;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? AppColors.lime : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(icon, color: selected ? AppColors.onLime : AppColors.lime),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label.toUpperCase(),
                            style: AppText.display(20,
                                weight: FontWeight.w700, color: selected ? AppColors.onLime : AppColors.text)),
                        const SizedBox(height: 2),
                        Text(description,
                            style: TextStyle(
                                fontSize: 14, color: selected ? AppColors.onLime : AppColors.textMuted)),
                      ],
                    ),
                  ),
                  if (selected) const Icon(Icons.check_circle_rounded, color: AppColors.onLime),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Big "− 4 +" stepper for workouts per week.
class WeeklyTargetPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const WeeklyTargetPicker({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          IconButton.filled(
            tooltip: 'Fewer',
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surfaceHigh,
              foregroundColor: AppColors.text,
              fixedSize: const Size(52, 52),
            ),
            icon: const Icon(Icons.remove_rounded),
          ),
          Expanded(
            child: Column(
              children: [
                Text('$value', style: AppText.display(56)),
                Text(value == 1 ? 'workout a week' : 'workouts a week', style: AppText.muted),
              ],
            ),
          ),
          IconButton.filled(
            tooltip: 'More',
            onPressed: value < 7 ? () => onChanged(value + 1) : null,
            style: IconButton.styleFrom(fixedSize: const Size(52, 52)),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _NumberInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? suffix;
  final bool decimal;
  final int? maxLength;

  const _NumberInput({
    required this.controller,
    required this.label,
    this.suffix,
    this.decimal = false,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.,]' : r'[0-9]')),
        if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
      ],
      decoration: InputDecoration(labelText: label, suffixText: suffix),
    );
  }
}
