import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import 'settings_provider.dart';

/// Settings shown at the bottom of the Profile tab.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
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
