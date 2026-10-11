import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/equipment.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../profile/profile_provider.dart';

/// Pick a preset or individual equipment you have access to.
class EquipmentScreen extends StatelessWidget {
  const EquipmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final have = profile.availableEquipment;

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text('EQUIPMENT', style: AppText.display(36)),
          const SizedBox(height: 6),
          const Text(
            "Exercises you can't do are flagged in your plans and workouts, with suggested swaps.",
            style: AppText.muted,
          ),
          const SizedBox(height: 20),
          const Text('QUICK SETUP', style: AppText.eyebrow),
          const SizedBox(height: 8),
          EquipmentPresetPicker(
            selected: have,
            onSelected: (equipment) => profile.setEquipment(equipment),
          ),
          const SizedBox(height: 20),
          const Text('OR PICK EXACTLY', style: AppText.eyebrow),
          const SizedBox(height: 8),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final code in Equipment.all)
                  CheckboxListTile(
                    value: have.contains(code),
                    activeColor: AppColors.lime,
                    checkColor: AppColors.onLime,
                    title: Text(Equipment.labels[code]!, style: AppText.strong),
                    onChanged: (on) {
                      final next = {...have};
                      on == true ? next.add(code) : next.remove(code);
                      profile.setEquipment(Equipment.all.where(next.contains).toList());
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The equipment presets as selectable cards.
class EquipmentPresetPicker extends StatelessWidget {
  final Set<String> selected;
  final ValueChanged<List<String>> onSelected;

  const EquipmentPresetPicker({super.key, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (name, description, equipment) in equipmentPresets)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Builder(builder: (context) {
              final isSelected = selected.length == equipment.length && selected.containsAll(equipment);
              return Semantics(
                selected: isSelected,
                button: true,
                child: Material(
                  color: isSelected ? AppColors.lime : AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => onSelected(equipment),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name.toUpperCase(),
                                    style: AppText.display(18,
                                        weight: FontWeight.w700,
                                        color: isSelected ? AppColors.onLime : AppColors.text)),
                                Text(description,
                                    style: TextStyle(
                                        fontSize: 13, color: isSelected ? AppColors.onLime : AppColors.textMuted)),
                              ],
                            ),
                          ),
                          if (isSelected) const Icon(Icons.check_circle_rounded, color: AppColors.onLime),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
      ],
    );
  }
}
