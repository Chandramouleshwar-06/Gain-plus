import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../utils/units.dart';
import '../profile/profile_provider.dart';
import '../../data/equipment.dart';
import 'equipment_screen.dart';
import 'notification_settings_screen.dart';
import 'settings_provider.dart';

/// Settings shown at the bottom of the Profile tab.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final profile = context.watch<ProfileProvider>();
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.straighten_rounded),
            title: const Text('Units', style: AppText.strong),
            trailing: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('kg')),
                ButtonSegment(value: true, label: Text('lb')),
              ],
              selected: {profile.units.isLb},
              onSelectionChanged: (s) => profile.setUnits(s.first ? const Units.lb() : const Units.kg()),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.lime,
                selectedForegroundColor: AppColors.onLime,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          const Divider(indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.fitness_center_rounded),
            title: const Text('Equipment', style: AppText.strong),
            subtitle: Text(_equipmentSummary(profile.availableEquipment), style: AppText.muted),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EquipmentScreen())),
          ),
          const Divider(indent: 16, endIndent: 16),
          SwitchListTile(
            value: settings.restTimerEnabled,
            onChanged: settings.setRestTimerEnabled,
            secondary: const Icon(Icons.timer_outlined),
            title: const Text('Rest timer', style: AppText.strong),
            subtitle: const Text('Starts when you tick off a set', style: AppText.muted),
          ),
          ListTile(
            enabled: settings.restTimerEnabled,
            leading: const Icon(Icons.hourglass_bottom_rounded),
            title: const Text('Rest length', style: AppText.strong),
            trailing: Text(formatRest(settings.restSeconds),
                style: AppText.display(20, weight: FontWeight.w700, color: AppColors.lime)),
            onTap: () => _pickRest(context, settings),
          ),
          const Divider(indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notifications', style: AppText.strong),
            subtitle: const Text('Reminders, quiet hours and limits', style: AppText.muted),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  void _pickRest(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('REST LENGTH', style: AppText.display(26)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final seconds in SettingsProvider.restOptions)
                    ChoiceChip(
                      label: Text(formatRest(seconds)),
                      selected: settings.restSeconds == seconds,
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        color: settings.restSeconds == seconds ? AppColors.onLime : AppColors.text,
                        fontWeight: FontWeight.w700,
                      ),
                      onSelected: (_) {
                        settings.setRestSeconds(seconds);
                        Navigator.pop(sheetContext);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _equipmentSummary(Set<String> have) {
  for (final (name, _, equipment) in equipmentPresets) {
    if (have.length == equipment.length && have.containsAll(equipment)) return name;
  }
  return '${have.length} of ${Equipment.all.length} items';
}
