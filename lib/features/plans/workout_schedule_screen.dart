import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import 'plans_provider.dart';

class WorkoutScheduleScreen extends StatefulWidget {
  const WorkoutScheduleScreen({super.key});

  @override
  State<WorkoutScheduleScreen> createState() => _WorkoutScheduleScreenState();
}

class _WorkoutScheduleScreenState extends State<WorkoutScheduleScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Workout Schedule',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onFormatChanged: (format) {
                if (_calendarFormat != format) {
                  setState(() => _calendarFormat = format);
                }
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
              calendarStyle: const CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: AppTheme.accentBlue,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                defaultTextStyle: TextStyle(color: AppTheme.textPrimary),
                weekendTextStyle: TextStyle(color: AppTheme.textSecondary),
                outsideTextStyle: TextStyle(color: Colors.grey),
              ),
              headerStyle: const HeaderStyle(
                titleTextStyle: TextStyle(color: AppTheme.textPrimary, fontSize: 18),
                formatButtonVisible: false,
                leftChevronIcon: Icon(Icons.chevron_left, color: AppTheme.textPrimary),
                rightChevronIcon: Icon(Icons.chevron_right, color: AppTheme.textPrimary),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Consumer<PlansProvider>(
                builder: (context, provider, child) {
                  final scheduledPlan = _selectedDay != null ? provider.planForDate(_selectedDay!) : null;

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Plan for ${_selectedDay?.day}/${_selectedDay?.month}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_alarm, color: AppTheme.accentBlue),
                            onPressed: () => _showSchedulePicker(context, _selectedDay!),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (scheduledPlan != null)
                        AppCard(
                          child: Row(
                            children: [
                              const Icon(Icons.event_available, color: AppTheme.accentBlue, size: 32),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      scheduledPlan.name,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    const Text(
                                      'Notification scheduled!',
                                      style: TextStyle(color: Colors.green, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              children: [
                                const Icon(Icons.event_busy, color: AppTheme.textSecondary, size: 48),
                                const SizedBox(height: 8),
                                Text(
                                  'Nothing scheduled yet',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSchedulePicker(BuildContext context, DateTime date) {
    int selectedWeeks = 1;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Consumer<PlansProvider>(
              builder: (context, provider, child) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Schedule Workout', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 20),
                      const Text('Repeat for how many weeks?', style: TextStyle(color: AppTheme.textSecondary)),
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 16),
                        // Wrap, not Row: five chips are wider than a phone screen.
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final w in [1, 2, 4, 8, 12])
                              ChoiceChip(
                                label: Text(w == 1 ? '1 week' : '$w weeks'),
                                selected: selectedWeeks == w,
                                onSelected: (selected) {
                                  if (selected) setModalState(() => selectedWeeks = w);
                                },
                                selectedColor: AppTheme.accentBlue,
                                labelStyle: TextStyle(color: selectedWeeks == w ? Colors.white : AppTheme.textPrimary),
                              ),
                          ],
                        ),
                      ),
                      const Text('Select Workout Plan:', style: TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(height: 8),
                      if (provider.plans.isEmpty)
                        const Text('No plans available. Create one first!')
                      else
                        Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: provider.plans.length,
                            itemBuilder: (context, index) {
                              final plan = provider.plans[index];
                              return ListTile(
                                leading: const Icon(Icons.fitness_center, color: AppTheme.accentBlue),
                                title: Text(plan.name, style: const TextStyle(color: AppTheme.textPrimary)),
                                onTap: () async {
                                  final navigator = Navigator.of(context);
                                  final messenger = ScaffoldMessenger.of(context);
                                  
                                  final TimeOfDay? time = await showTimePicker(
                                    context: context,
                                    initialTime: const TimeOfDay(hour: 8, minute: 0),
                                  );
                                  
                                  if (time != null && mounted) {
                                    await provider.scheduleWorkout(
                                      date, 
                                      plan.id, 
                                      time, 
                                      repeatWeeks: selectedWeeks
                                    );
                                    if (mounted) {
                                      navigator.pop();
                                      messenger.showSnackBar(
                                        SnackBar(content: Text('Scheduled ${plan.name} for $selectedWeeks weeks!')),
                                      );
                                    }
                                  }
                                },
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 20),
                    ],
                  ),
                );
              },
            );
          }
        );
      },
    );
  }
}
