import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../data/builtin_foods.dart';
import '../../data/sync_columns.dart';
import '../../models/food.dart';
import '../../services/open_food_facts.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/primary_button.dart';
import 'nutrition_provider.dart';

/// Find a food (yours, built-in, or online) and log it to [meal].
class FoodSearchScreen extends StatefulWidget {
  final String meal;
  const FoodSearchScreen({super.key, required this.meal});

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  final _search = OpenFoodFacts();
  Timer? _debounce;
  String _query = '';
  bool _searching = false;
  String? _onlineError;
  List<Food> _online = [];

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onQuery(String value) {
    setState(() => _query = value.trim());
    _debounce?.cancel();
    if (_query.length < 3) {
      setState(() {
        _online = [];
        _onlineError = null;
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () => _searchOnline(_query));
  }

  Future<void> _searchOnline(String query) async {
    setState(() {
      _searching = true;
      _onlineError = null;
    });
    try {
      final results = await _search.search(query);
      if (!mounted || query != _query) return;
      setState(() => _online = results);
    } catch (_) {
      if (!mounted || query != _query) return;
      setState(() {
        _online = [];
        _onlineError = "Couldn't search online. You may be offline; built-in and your own foods still work.";
      });
    } finally {
      if (mounted && query == _query) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nutrition = context.watch<NutritionProvider>();
    final q = _query.toLowerCase();
    bool matches(Food f) => f.name.toLowerCase().contains(q) || (f.brand?.toLowerCase().contains(q) ?? false);
    final local = q.isEmpty ? <Food>[] : [...nutrition.savedFoods, ...builtinFoods].where(matches).toList();

    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Text(text, style: AppText.eyebrow),
        );

    return Scaffold(
      appBar: AppBar(title: Text('ADD TO ${mealLabel(widget.meal).toUpperCase()}', style: AppText.display(22))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search foods, e.g. dal, paneer, a brand',
                prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted),
              ),
              onChanged: _onQuery,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _quickAdd(context),
                    icon: const Icon(Icons.bolt_rounded, size: 18),
                    label: const Text('Quick add'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.text, minimumSize: const Size(0, 44)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _createFood(context),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Create food'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.text, minimumSize: const Size(0, 44)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                if (q.isEmpty) ...[
                  if (nutrition.recentFoods.isNotEmpty) ...[
                    header('RECENT'),
                    for (final f in nutrition.recentFoods) _FoodTile(food: f, onTap: () => _pickPortion(context, f)),
                  ],
                  header('COMMON FOODS'),
                  for (final f in builtinFoods) _FoodTile(food: f, onTap: () => _pickPortion(context, f)),
                ] else ...[
                  if (local.isNotEmpty) ...[
                    header('YOUR FOODS AND COMMON FOODS'),
                    for (final f in local) _FoodTile(food: f, onTap: () => _pickPortion(context, f)),
                  ],
                  header('ONLINE · OPEN FOOD FACTS'),
                  if (_query.length < 3)
                    const _Note('Type at least 3 letters to search online.')
                  else if (_searching)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator(color: AppColors.lime)),
                    )
                  else if (_onlineError != null)
                    _Note(_onlineError!)
                  else if (_online.isEmpty)
                    const _Note('No online results.')
                  else
                    for (final f in _online) _FoodTile(food: f, onTap: () => _pickPortion(context, f)),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPortion(BuildContext context, Food food) async {
    final navigator = Navigator.of(context);
    final logged = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PortionSheet(food: food, meal: widget.meal),
    );
    if (logged == true) navigator.pop();
  }

  Future<void> _quickAdd(BuildContext context) async {
    final food = await showModalBottomSheet<Food>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _FoodForm(quick: true),
    );
    if (food == null || !context.mounted) return;
    await context.read<NutritionProvider>().log(food, meal: widget.meal, servings: 1);
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _createFood(BuildContext context) async {
    final food = await showModalBottomSheet<Food>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _FoodForm(quick: false),
    );
    if (food != null && context.mounted) await _pickPortion(context, food);
  }
}

class _Note extends StatelessWidget {
  final String text;
  const _Note(this.text);

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 8), child: Text(text, style: AppText.muted));
}

class _FoodTile extends StatelessWidget {
  final Food food;
  final VoidCallback onTap;
  const _FoodTile({required this.food, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(food.name, style: AppText.strong, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [if (food.brand != null) food.brand!, food.servingName, '${food.protein.round()} g protein'].join(' · '),
        style: AppText.muted,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text('${food.kcal.round()} kcal', style: AppText.strong),
    );
  }
}

/// How much was eaten: servings with quick picks, and the resulting totals.
class _PortionSheet extends StatefulWidget {
  final Food food;
  final String meal;
  const _PortionSheet({required this.food, required this.meal});

  @override
  State<_PortionSheet> createState() => _PortionSheetState();
}

class _PortionSheetState extends State<_PortionSheet> {
  double _servings = 1;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.food;
    Widget stat(String label, double v, [String unit = 'g']) => Expanded(
          child: Column(
            children: [
              Text('${(v * _servings).round()}${unit == 'kcal' ? '' : ' g'}', style: AppText.display(22)),
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
        );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(f.name.toUpperCase(), style: AppText.display(24), maxLines: 2, overflow: TextOverflow.ellipsis),
            Text('1 serving = ${f.servingName}', style: AppText.muted),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filled(
                  tooltip: 'Less',
                  onPressed: _servings > 0.25 ? () => setState(() => _servings -= 0.25) : null,
                  style: IconButton.styleFrom(backgroundColor: AppColors.surfaceHigh, foregroundColor: AppColors.text),
                  icon: const Icon(Icons.remove_rounded),
                ),
                SizedBox(
                  width: 120,
                  child: Column(
                    children: [
                      Text(formatWeight(_servings), style: AppText.display(40)),
                      Text(_servings == 1 ? 'serving' : 'servings', style: AppText.muted),
                    ],
                  ),
                ),
                IconButton.filled(
                  tooltip: 'More',
                  onPressed: () => setState(() => _servings += 0.25),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                for (final s in [0.5, 1.0, 1.5, 2.0, 3.0])
                  ChoiceChip(
                    label: Text(formatWeight(s)),
                    selected: _servings == s,
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      color: _servings == s ? AppColors.onLime : AppColors.text,
                      fontWeight: FontWeight.w700,
                    ),
                    onSelected: (_) => setState(() => _servings = s),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(children: [
              stat('kcal', f.kcal, 'kcal'),
              stat('protein', f.protein),
              stat('carbs', f.carbs),
              stat('fat', f.fat),
            ]),
            const SizedBox(height: 20),
            PrimaryButton(
              text: 'Add to ${mealLabel(widget.meal)}',
              onPressed: _saving
                  ? null
                  : () async {
                      setState(() => _saving = true);
                      final navigator = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await context.read<NutritionProvider>().log(f, meal: widget.meal, servings: _servings);
                        navigator.pop(true);
                      } catch (e) {
                        debugPrint('Could not log food: $e');
                        if (mounted) setState(() => _saving = false);
                        messenger.showSnackBar(const SnackBar(content: Text("Couldn't add it. Please try again.")));
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}

/// Create a food, or (with [quick]) just enter calories and protein.
class _FoodForm extends StatefulWidget {
  final bool quick;
  const _FoodForm({required this.quick});

  @override
  State<_FoodForm> createState() => _FoodFormState();
}

class _FoodFormState extends State<_FoodForm> {
  final _name = TextEditingController();
  final _serving = TextEditingController(text: '1 serving');
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _serving, _kcal, _protein, _carbs, _fat]) {
      c.dispose();
    }
    super.dispose();
  }

  double _n(TextEditingController c) => parseDecimal(c.text) ?? 0;

  void _submit() {
    final kcal = _n(_kcal);
    final name = widget.quick ? 'Quick add' : _name.text.trim();
    if (kcal <= 0 || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.quick ? 'Enter the calories.' : 'Enter a name and the calories.')),
      );
      return;
    }
    Navigator.pop(
      context,
      Food(
        id: widget.quick ? 'quick-${newId()}' : newId(),
        name: name,
        servingName: widget.quick ? '1 entry' : (_serving.text.trim().isEmpty ? '1 serving' : _serving.text.trim()),
        kcal: kcal,
        protein: _n(_protein),
        carbs: _n(_carbs),
        fat: _n(_fat),
        source: widget.quick ? 'quick' : 'custom',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    TextField number(TextEditingController c, String label, [String suffix = 'g']) => TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          decoration: InputDecoration(labelText: label, suffixText: suffix),
        );

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.quick ? 'QUICK ADD' : 'NEW FOOD', style: AppText.display(26)),
            const SizedBox(height: 16),
            if (!widget.quick) ...[
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _serving,
                decoration: const InputDecoration(labelText: 'Serving', hintText: 'e.g. 1 bowl, 100 g'),
              ),
              const SizedBox(height: 12),
            ],
            Row(children: [
              Expanded(child: number(_kcal, 'Calories', 'kcal')),
              const SizedBox(width: 12),
              Expanded(child: number(_protein, 'Protein')),
            ]),
            if (!widget.quick) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: number(_carbs, 'Carbs')),
                const SizedBox(width: 12),
                Expanded(child: number(_fat, 'Fat')),
              ]),
            ],
            const SizedBox(height: 20),
            PrimaryButton(text: widget.quick ? 'Add' : 'Save food', onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
