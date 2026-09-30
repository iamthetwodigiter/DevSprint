import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../services/hive_service.dart';
import '../../services/user_preferences_service.dart';
import '../widgets/activity_widgets.dart';
import '../widgets/app_card.dart';
import '../widgets/app_page.dart';
import 'sprint_details_screen.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  DateTime focusedDay = DateTime.now();
  DateTime? selectedDay;
  Set<String> selectedWidgets = {};
  bool loadingWidgets = true;

  static const _widgetDefinitions = <String, String>{
    'today': 'Today activity',
    'momentum': 'Momentum',
    'monthly': 'Monthly activity',
    'heatmap': 'Activity heatmap',
    'weekly': 'Weekly rhythm',
    'skills': 'Skill matrix',
    'scores': 'Score progression',
    'weak_spots': 'Weak spots',
    'recent_explored': 'Recently explored',
    'year_review': 'Developer year in review',
    'dna': 'Developer DNA',
  };

  final preferences = UserPreferencesService();

  @override
  void initState() {
    super.initState();
    _loadWidgetSelection();
  }

  Future<void> _loadWidgetSelection() async {
    final widgets = await preferences.loadProgressWidgets();
    if (!mounted) return;
    setState(() {
      selectedWidgets = widgets;
      loadingWidgets = false;
    });
  }

  Future<void> _editWidgets(List<Map<String, dynamic>> records) async {
    final working = {...selectedWidgets};
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Customize progress widgets'),
            content: SizedBox(
              width: 620,
              child: SingleChildScrollView(
                child: Column(
                  children: _widgetDefinitions.entries.map((entry) {
                    final enabled = working.contains(entry.key);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              title: Text(entry.value),
                              subtitle: Text(
                                enabled
                                    ? 'Shown on the Progress page'
                                    : 'Hidden by default',
                              ),
                              value: enabled,
                              onChanged: (value) => setDialogState(() {
                                if (value) {
                                  working.add(entry.key);
                                } else {
                                  working.remove(entry.key);
                                }
                              }),
                            ),
                            const SizedBox(height: 8),
                            _widgetPreview(context, entry.key, records),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  await preferences.saveProgressWidgets(working);
                  if (!mounted) return;
                  setState(() => selectedWidgets = {...working});
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _widgetPreview(
    BuildContext context,
    String id,
    List<Map<String, dynamic>> records,
  ) {
    final month = focusedDay;
    return switch (id) {
      'today' => TodayActivityCard(records: records),
      'momentum' => MomentumCard(records: records),
      'monthly' => MonthlyActivityCard(records: records, month: month),
      'heatmap' => ActivityHeatmap(records: records, month: month),
      'weekly' => WeeklyRhythmCard(
        records: records,
        anchor: selectedDay ?? DateTime.now(),
      ),
      'skills' => SkillMatrixCard(records: records),
      'scores' => ScoreProgressionCard(records: records),
      'weak_spots' => WeakSpotsCard(records: records),
      'recent_explored' => RecentExploredCard(records: records),
      'year_review' => DeveloperYearReviewCard(
        records: records,
        year: DateTime.now().year,
      ),
      'dna' => DeveloperDnaCard(records: records),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(hiveServiceProvider).getSprintRecords();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final passed = records.where((e) => e['success'] == true).toList();
    final failed = records.where((e) => e['success'] != true).toList();
    final average = DevSprintAnalytics.averageScore(records);
    final selectedRecords = selectedDay == null
        ? records
        : records.where((record) {
            final date = DateTime.tryParse(
              record['completedAt'] as String? ?? '',
            );
            return date != null && isSameDay(date, selectedDay);
          }).toList();

    return AppPage(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          const AppPageHeader(
            eyebrow: 'Progress',
            title: 'See the work adding up.',
            subtitle: 'A clear record of what you practiced, finished, and learned.',
          ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: AppMetric(
                value: '${passed.length}',
                label: 'passed',
                icon: Icons.check_circle_outline_rounded,
                color: cs.primary,
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: AppMetric(
                value: '${failed.length}',
                label: 'needs another run',
                icon: Icons.replay_rounded,
                color: cs.error,
                
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: AppMetric(
                value: records.isEmpty ? '—' : average.toStringAsFixed(0),
                label: 'average score',
                icon: Icons.grade_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        AppCard(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.dashboard_customize_rounded,
                  color: cs.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progress widgets',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      loadingWidgets || selectedWidgets.isEmpty
                          ? 'Optional analytics are hidden by default.'
                          : '${selectedWidgets.length} widget${selectedWidgets.length == 1 ? '' : 's'} enabled',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: loadingWidgets ? null : () => _editWidgets(records),
                icon: const Icon(Icons.tune_rounded),
                label: const Text('Edit'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ...selectedWidgets
            .map((id) => _selectedWidget(context, id, records))
            .whereType<Widget>()
            .expand((widget) => [widget, const SizedBox(height: 12)]),
        Text(
          'Calendar',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        AppCard(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
          child: TableCalendar<Map<String, dynamic>>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2035, 12, 31),
            focusedDay: focusedDay,
            selectedDayPredicate: (day) => isSameDay(day, selectedDay),
            onDaySelected: (selected, focused) {
              setState(() {
                selectedDay = selected;
                focusedDay = focused;
              });
            },
            onPageChanged: (focused) => setState(() => focusedDay = focused),
            eventLoader: (day) => records.where((record) {
              final date = DateTime.tryParse(
                record['completedAt'] as String? ?? '',
              );
              return date != null && isSameDay(date, day);
            }).toList(),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              todayDecoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              todayTextStyle: TextStyle(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
              selectedDecoration: BoxDecoration(
                color: cs.primary,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            calendarBuilders: CalendarBuilders<Map<String, dynamic>>(
              markerBuilder: (context, day, events) {
                if (events.isEmpty) return null;
                final success = events.any((e) => e['success'] == true);
                final failed = events.any((e) => e['success'] != true);
                return Positioned(
                  bottom: 2,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (success)
                        Icon(
                          Icons.check_circle_rounded,
                          size: 13,
                          color: cs.primary,
                        ),
                      if (failed)
                        Icon(Icons.cancel_rounded, size: 13, color: cs.error),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          selectedDay == null
              ? 'Recent runs'
              : 'Runs on ${selectedDay!.day}/${selectedDay!.month}/${selectedDay!.year}',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        if (selectedRecords.isEmpty)
          AppCard(
            child: Text(
              selectedDay == null
                  ? 'Complete your first sprint and it will appear here.'
                  : 'No sprint recorded on this date.',
            ),
          )
        else
          ...selectedRecords.map((record) => _recordCard(context, record)),
        ],
      ),
    );
  }

  Widget? _selectedWidget(
    BuildContext context,
    String id,
    List<Map<String, dynamic>> records,
  ) {
    return switch (id) {
      'today' => TodayActivityCard(records: records),
      'momentum' => MomentumCard(records: records),
      'monthly' => MonthlyActivityCard(records: records, month: focusedDay),
      'heatmap' => ActivityHeatmap(
        records: records,
        month: focusedDay,
        onDayTap: (day) => setState(() => selectedDay = day),
      ),
      'weekly' => WeeklyRhythmCard(
        records: records,
        anchor: selectedDay ?? DateTime.now(),
      ),
      'skills' => SkillMatrixCard(records: records),
      'scores' => ScoreProgressionCard(records: records),
      'weak_spots' => WeakSpotsCard(records: records),
      'recent_explored' => RecentExploredCard(records: records),
      'year_review' => DeveloperYearReviewCard(
        records: records,
        year: DateTime.now().year,
      ),
      'dna' => DeveloperDnaCard(records: records),
      _ => null,
    };
  }

  Widget _recordCard(BuildContext context, Map<String, dynamic> record) {
    final cs = Theme.of(context).colorScheme;
    final success = record['success'] == true;
    final task = Map<String, dynamic>.from(record['task'] ?? {});
    final score = (record['score'] as num?)?.toInt() ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SprintDetailsScreen(record: record),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: success ? cs.primary : cs.error,
                width: 1.2,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: (success ? cs.primary : cs.error).withValues(
                      alpha: 0.12,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    success ? Icons.check_rounded : Icons.close_rounded,
                    color: success ? cs.primary : cs.error,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task['title'] as String? ?? 'Sprint',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        success ? 'Passed' : 'Failed',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: success ? cs.primary : cs.error,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$score/100',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }


}
