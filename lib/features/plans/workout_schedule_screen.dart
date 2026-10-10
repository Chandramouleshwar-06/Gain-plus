import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_keys.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button.dart';
import '../workout/workout_launcher.dart';
import 'plans_provider.dart';

/// The Schedule section of the Train tab.
class ScheduleView extends StatefulWidget {
  const ScheduleView({super.key});

  @override
  State<ScheduleView> createState() => _ScheduleViewState();
}

class _ScheduleViewState extends State<ScheduleView> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlansProvider>();
    final scheduledPlan = provider.planForDate(_selectedDay);
    final entry = provider.schedules[dateKey(_selectedDay)];
    final today = DateTime.now();
    final isPast = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day)
        .isBefore(DateTime(today.year, today.month, today.day));

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      children: [
        TableCalendar(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2035, 12, 31),
          focusedDay: _focusedDay,
          startingDayOfWeek: StartingDayOfWeek.monday,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          eventLoader: (day) => provider.schedules.containsKey(dateKey(day)) ? const [true] : const [],
          onDaySelected: (selectedDay, focusedDay) => setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          }),
          onPageChanged: (focusedDay) => _focusedDay = focusedDay,
          availableCalendarFormats: const {CalendarFormat.month: 'Month'},
          headerStyle: HeaderStyle(
            titleCentered: true,
            formatButtonVisible: false,
            titleTextStyle: AppText.display(22, weight: FontWeight.w700),
            leftChevronIcon: const Icon(Icons.chevron_left_rounded, color: AppColors.text),
            rightChevronIcon: const Icon(Icons.chevron_right_rounded, color: AppColors.text),
          ),
          daysOfWeekStyle: const DaysOfWeekStyle(
            weekdayStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted),
            weekendStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted),
          ),
          calendarStyle: const CalendarStyle(
            defaultTextStyle: TextStyle(color: AppColors.text, fontWeight: FontWeight.w600),
            weekendTextStyle: TextStyle(color: AppColors.text, fontWeight: FontWeight.w600),
            outsideTextStyle: TextStyle(color: AppColors.textFaint),
            todayDecoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.fromBorderSide(BorderSide(color: AppColors.lime, width: 2)),
            ),
            todayTextStyle: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800),
            selectedDecoration: BoxDecoration(color: AppColors.lime, shape: BoxShape.circle),
            selectedTextStyle: TextStyle(color: AppColors.onLime, fontWeight: FontWeight.w800),
            markerDecoration: BoxDecoration(color: AppColors.orange, shape: BoxShape.circle),
            markersMaxCount: 1,
            markerSize: 6,
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(DateFormat('EEEE d MMMM').format(_selectedDay).toUpperCase(), style: AppText.eyebrow),
              const SizedBox(height: 10),
              if (scheduledPlan != null)
                AppCard(
                  padding: const EdgeInsets.fromLTRB(18, 16, 8, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(scheduledPlan.name.toUpperCase(),
                                style: AppText.display(24, weight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(
                              entry?.reminderMinutes == null
                                  ? 'No reminder'
                                  : 'Reminder at ${_formatMinutes(context, entry!.reminderMinutes!)}',
                              style: AppText.muted,
                            ),
                          ],
                        ),
                      ),
                      if (isSameDay(_selectedDay, today))
                        IconButton(
                          tooltip: 'Start now',
                          onPressed: () => startPlanWorkout(context, scheduledPlan),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.lime,
                            foregroundColor: AppColors.onLime,
                          ),
                          icon: const Icon(Icons.play_arrow_rounded),
                        ),
                      if (!isPast)
                        IconButton(
                          tooltip: 'Unschedule',
                          icon: const Icon(Icons.event_busy_rounded, color: AppColors.textMuted),
                          onPressed: () => provider.unschedule(_selectedDay),
                        ),
                    ],
                  ),
                )
              else
                AppCard(
                  child: Text(isPast ? 'Nothing was scheduled.' : 'Nothing scheduled yet.', style: AppText.muted),
                ),
              if (!isPast) ...[
                const SizedBox(height: 12),
                PrimaryButton(
                  text: scheduledPlan == null ? 'Schedule a workout' : 'Change workout',
                  icon: Icons.add_alarm_rounded,
                  variant: scheduledPlan == null ? ButtonVariant.primary : ButtonVariant.secondary,
                  onPressed: () => _showSchedulePicker(context, _selectedDay),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _formatMinutes(BuildContext context, int minutes) =>
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context);

  void _showSchedulePicker(BuildContext context, DateTime date) {
    int selectedWeeks = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final provider = sheetContext.watch<PlansProvider>();
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SCHEDULE WORKOUT', style: AppText.display(26)),
                    const SizedBox(height: 16),
                    const Text('REPEAT EVERY WEEK FOR', style: AppText.eyebrow),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final w in [1, 2, 4, 8, 12])
                          ChoiceChip(
                            label: Text(w == 1 ? 'Just once' : '$w weeks'),
                            selected: selectedWeeks == w,
                            showCheckmark: false,
                            labelStyle: TextStyle(
                              color: selectedWeeks == w ? AppColors.onLime : AppColors.text,
                              fontWeight: FontWeight.w700,
                            ),
                            onSelected: (_) => setSheetState(() => selectedWeeks = w),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text('PLAN', style: AppText.eyebrow),
                    const SizedBox(height: 4),
                    if (provider.plans.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('No plans yet. Create one in Plans first.', style: AppText.muted),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: provider.plans.length,
                          itemBuilder: (_, index) {
                            final plan = provider.plans[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.fitness_center_rounded, color: AppColors.lime),
                              title: Text(plan.name, style: AppText.strong),
                              onTap: () => _schedule(sheetContext, date, plan.id, plan.name, selectedWeeks),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _schedule(BuildContext sheetContext, DateTime date, String planId, String planName, int weeks) async {
    final navigator = Navigator.of(sheetContext);
    final messenger = ScaffoldMessenger.of(sheetContext);
    final provider = sheetContext.read<PlansProvider>();

    final time = await showTimePicker(
      context: sheetContext,
      initialTime: const TimeOfDay(hour: 18, minute: 0),
      helpText: 'REMIND ME AT',
    );
    if (time == null) return;

    await provider.scheduleWorkout(date, planId, time, repeatWeeks: weeks);
    navigator.pop();
    messenger.showSnackBar(SnackBar(
      content: Text(weeks == 1 ? 'Scheduled $planName.' : 'Scheduled $planName for $weeks weeks.'),
    ));
  }
}
