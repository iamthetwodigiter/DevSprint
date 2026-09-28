import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'app_card.dart';

class DevSprintAnalytics {
  static List<Map<String, dynamic>> sorted(List<Map<String, dynamic>> records) {
    final result = [...records];
    result.sort((a, b) {
      final ad =
          DateTime.tryParse(a['completedAt'] as String? ?? '') ??
          DateTime(1970);
      final bd =
          DateTime.tryParse(b['completedAt'] as String? ?? '') ??
          DateTime(1970);
      return ad.compareTo(bd);
    });
    return result;
  }

  static int score(Map<String, dynamic> record) =>
      (record['score'] as num?)?.toInt() ?? 0;

  static Map<String, dynamic> task(Map<String, dynamic> record) =>
      Map<String, dynamic>.from(record['task'] ?? const {});

  static String category(Map<String, dynamic> record) =>
      task(record)['practice_type'] as String? ?? 'Engineering';

  static String language(Map<String, dynamic> record) =>
      task(record)['language'] as String? ?? 'Unknown';

  static Duration duration(Map<String, dynamic> record) {
    final taskData = task(record);
    final minutes = (taskData['deadline_minutes'] as num?)?.toInt() ?? 0;
    return Duration(minutes: minutes);
  }

  static Map<String, List<Map<String, dynamic>>> byCategory(
    List<Map<String, dynamic>> records,
  ) {
    final result = <String, List<Map<String, dynamic>>>{};
    for (final record in records) {
      result.putIfAbsent(category(record), () => []).add(record);
    }
    return result;
  }

  static Map<String, List<Map<String, dynamic>>> byLanguage(
    List<Map<String, dynamic>> records,
  ) {
    final result = <String, List<Map<String, dynamic>>>{};
    for (final record in records) {
      result.putIfAbsent(language(record), () => []).add(record);
    }
    return result;
  }

  static int monthTotal(List<Map<String, dynamic>> records, DateTime month) =>
      records.where((record) {
        final date = DateTime.tryParse(record['completedAt'] as String? ?? '');
        return date != null &&
            date.year == month.year &&
            date.month == month.month;
      }).length;

  static int totalFocusedMinutes(List<Map<String, dynamic>> records) =>
      records.fold(0, (sum, record) => sum + duration(record).inMinutes);

  static double averageScore(List<Map<String, dynamic>> records) {
    if (records.isEmpty) return 0;
    return records.fold<int>(0, (sum, record) => sum + score(record)) /
        records.length;
  }
}

class ActivityHeatmap extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  final DateTime month;
  final ValueChanged<DateTime>? onDayTap;

  const ActivityHeatmap({
    super.key,
    required this.records,
    required this.month,
    this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final first = DateTime(month.year, month.month, 1);
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final leading = first.weekday - DateTime.monday;
    final cells = <DateTime?>[
      ...List<DateTime?>.filled(leading, null),
      ...List.generate(
        days,
        (index) => DateTime(month.year, month.month, index + 1),
      ),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    final byDay = <String, List<Map<String, dynamic>>>{};
    for (final record in records) {
      final date = DateTime.tryParse(record['completedAt'] as String? ?? '');
      if (date == null || date.year != month.year || date.month != month.month) {
        continue;
      }
      final key = _key(date);
      byDay.putIfAbsent(key, () => []).add(record);
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_monthName(month.month)} ${month.year}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${byDay.length} active days',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: const [
              'M',
              'T',
              'W',
              'T',
              'F',
              'S',
              'S',
            ].map((day) => Expanded(child: Center(child: Text(day)))).toList(),
          ),
          const SizedBox(height: 6),
          ...List.generate(cells.length ~/ 7, (row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: List.generate(7, (column) {
                  final day = cells[row * 7 + column];
                  if (day == null) {
                    return const Expanded(child: SizedBox(height: 34));
                  }
                  final events = byDay[_key(day)] ?? const [];
                  final success = events.any((e) => e['success'] == true);
                  final failed = events.any((e) => e['success'] != true);
                  final minutes = events.fold<int>(
                    0,
                    (sum, e) => sum + DevSprintAnalytics.duration(e).inMinutes,
                  );
                  final intensity = minutes >= 120
                      ? 4
                      : minutes >= 90
                      ? 3
                      : minutes >= 45
                      ? 2
                      : events.isNotEmpty
                      ? 1
                      : 0;
                  final base = success
                      ? cs.primary
                      : failed
                      ? cs.error
                      : cs.surfaceContainerHighest;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Semantics(
                        button: onDayTap != null,
                        label:
                            '${day.day} ${success
                                ? 'successful'
                                : failed
                                ? 'failed'
                                : 'no'} sprint',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(9),
                          onTap: onDayTap == null ? null : () => onDayTap!(day),
                          child: Container(
                            height: 34,
                            decoration: BoxDecoration(
                              color: intensity == 0
                                  ? base
                                  : base.withValues(
                                      alpha: 0.18 + intensity * 0.17,
                                    ),
                              borderRadius: BorderRadius.circular(9),
                              border: events.isEmpty
                                  ? null
                                  : Border.all(
                                      color: base.withValues(alpha: 0.7),
                                    ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${day.day}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: intensity == 0
                                    ? cs.onSurfaceVariant
                                    : base,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _Legend(color: cs.primary, label: 'completed'),
              _Legend(color: cs.error, label: 'failed'),
              _Legend(color: cs.outline, label: 'no sprint'),
            ],
          ),
        ],
      ),
    );
  }

  String _key(DateTime date) => '${date.year}-${date.month}-${date.day}';

  String _monthName(int month) => const [
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][month];
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class MonthlyActivityCard extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  final DateTime month;

  const MonthlyActivityCard({
    super.key,
    required this.records,
    required this.month,
  });

  @override
  Widget build(BuildContext context) {
    final total = DevSprintAnalytics.monthTotal(records, month);
    final monthRecords = records.where((record) {
      final date = DateTime.tryParse(record['completedAt'] as String? ?? '');
      return date != null &&
          date.year == month.year &&
          date.month == month.month;
    }).toList();
    final passed = monthRecords.where((e) => e['success'] == true).length;
    final minutes = DevSprintAnalytics.totalFocusedMinutes(monthRecords);
    final category = _topCategory(monthRecords);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly activity',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '${_month(month.month)} ${month.year}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _Metric(value: '$total', label: 'sprints'),
              ),
              Expanded(
                child: _Metric(value: '$passed', label: 'passed'),
              ),
              Expanded(
                child: _Metric(value: '${minutes}m', label: 'focused'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            category == null
                ? 'Your first sprint will establish your strongest practice area.'
                : 'Most practiced: $category',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String? _topCategory(List<Map<String, dynamic>> records) {
    if (records.isEmpty) return null;
    final counts = <String, int>{};
    for (final record in records) {
      counts.update(
        DevSprintAnalytics.category(record),
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  String _month(int month) => const [
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][month];
}

class WeeklyRhythmCard extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  final DateTime anchor;

  const WeeklyRhythmCard({
    super.key,
    required this.records,
    required this.anchor,
  });

  @override
  Widget build(BuildContext context) {
    final start = DateTime(
      anchor.year,
      anchor.month,
      anchor.day,
    ).subtract(Duration(days: anchor.weekday - 1));
    final days = List.generate(7, (i) => start.add(Duration(days: i)));
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final active = days
        .where((day) => records.any((r) => _sameDay(r, day)))
        .length;
    final passed = days
        .where(
          (day) => records.any((r) => _sameDay(r, day) && r['success'] == true),
        )
        .length;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Weekly rhythm',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$active sessions · $passed successful',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: days.map((day) {
              final dayRecords = records
                  .where((r) => _sameDay(r, day))
                  .toList();
              final success = dayRecords.any((r) => r['success'] == true);
              final failed = dayRecords.isNotEmpty && !success;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    children: [
                      Text(
                        _weekday(day.weekday),
                        style: theme.textTheme.labelSmall,
                      ),
                      const SizedBox(height: 7),
                      Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: dayRecords.isEmpty
                              ? cs.surfaceContainerHighest
                              : (success ? cs.primary : cs.error).withValues(
                                  alpha: 0.15,
                                ),
                          borderRadius: BorderRadius.circular(12),
                          border: dayRecords.isEmpty
                              ? null
                              : Border.all(
                                  color: success ? cs.primary : cs.error,
                                ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          dayRecords.isEmpty
                              ? Icons.remove_rounded
                              : success
                              ? Icons.check_rounded
                              : failed
                              ? Icons.close_rounded
                              : Icons.remove_rounded,
                          size: 19,
                          color: dayRecords.isEmpty
                              ? cs.outline
                              : success
                              ? cs.primary
                              : cs.error,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  bool _sameDay(Map<String, dynamic> record, DateTime day) {
    final date = DateTime.tryParse(record['completedAt'] as String? ?? '');
    return date != null &&
        date.year == day.year &&
        date.month == day.month &&
        date.day == day.day;
  }

  String _weekday(int weekday) =>
      const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][weekday - 1];
}

class SkillMatrixCard extends StatelessWidget {
  final List<Map<String, dynamic>> records;

  const SkillMatrixCard({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final groups = DevSprintAnalytics.byCategory(records);
    final entries = groups.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    if (entries.isEmpty) {
      return const AppCard(
        child: _EmptyWidget(
          title: 'Skill development',
          message: 'Complete a sprint to start building your practice map.',
        ),
      );
    }

    final max = entries.map((e) => e.value.length).reduce(math.max);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Skill development',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Where your time has actually gone.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          ...entries.take(8).map((entry) {
            final avg = DevSprintAnalytics.averageScore(entry.value);
            final value = entry.value.length / max;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${entry.value.length} · ${avg.round()} avg',
                        style: theme.textTheme.labelMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(value: value, minHeight: 7),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class MomentumCard extends StatelessWidget {
  final List<Map<String, dynamic>> records;

  const MomentumCard({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    final recent = DevSprintAnalytics.sorted(records).reversed.take(7).toList();
    final previous = DevSprintAnalytics.sorted(records).reversed
        .skip(7)
        .take(7)
        .toList();
    final recentAvg = DevSprintAnalytics.averageScore(recent);
    final previousAvg = DevSprintAnalytics.averageScore(previous);
    final successRate = recent.isEmpty
        ? 0.0
        : recent.where((r) => r['success'] == true).length / recent.length;
    final activity = math.min(1.0, recent.length / 7);
    final scoreFactor = recentAvg / 100;
    final momentum =
        ((activity * 0.35 + scoreFactor * 0.35 + successRate * 0.30) * 100)
            .round();
    final delta = previous.isEmpty ? null : (recentAvg - previousAvg).round();
    final cs = Theme.of(context).colorScheme;

    return AppCard(
      child: Row(
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: momentum / 100,
                  strokeWidth: 8,
                ),
                Text(
                  '$momentum',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Momentum',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  momentum >= 75
                      ? 'Strong'
                      : momentum >= 50
                      ? 'Building'
                      : 'Warming up',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  delta == null
                      ? 'Your recent activity is establishing a baseline.'
                      : '${delta >= 0 ? '+' : ''}$delta average score vs the previous window.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ScoreProgressionCard extends StatelessWidget {
  final List<Map<String, dynamic>> records;

  const ScoreProgressionCard({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    final sorted = DevSprintAnalytics.sorted(records);
    final scores = sorted.map(DevSprintAnalytics.score).toList();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Score progression',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Your most recent evaluations, oldest to newest.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
          SizedBox(height: 170, child: _ScoreChart(scores: scores)),
        ],
      ),
    );
  }
}

class _ScoreChart extends StatelessWidget {
  final List<int> scores;
  const _ScoreChart({required this.scores});

  @override
  Widget build(BuildContext context) {
    if (scores.isEmpty) {
      return const _EmptyWidget(
        title: '',
        message: 'Your score line will appear after your first evaluation.',
      );
    }
    return CustomPaint(
      painter: _ScoreChartPainter(
        scores: scores,
        lineColor: Theme.of(context).colorScheme.primary,
        gridColor: Theme.of(context).colorScheme.outlineVariant,
        textColor: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _ScoreChartPainter extends CustomPainter {
  final List<int> scores;
  final Color lineColor;
  final Color gridColor;
  final Color textColor;

  _ScoreChartPainter({
    required this.scores,
    required this.lineColor,
    required this.gridColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final left = 30.0;
    final top = 8.0;
    final right = 8.0;
    final bottom = 22.0;
    final chart = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final grid = Paint()
      ..color = gridColor.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (final value in [0, 25, 50, 75, 100]) {
      final y = chart.bottom - (value / 100) * chart.height;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
      textPainter.text = TextSpan(
        text: '$value',
        style: TextStyle(color: textColor, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, y - textPainter.height / 2));
    }

    final points = <Offset>[];
    for (var i = 0; i < scores.length; i++) {
      final x = scores.length == 1
          ? chart.center.dx
          : chart.left + (i / (scores.length - 1)) * chart.width;
      final y = chart.bottom - (scores[i].clamp(0, 100) / 100) * chart.height;
      points.add(Offset(x, y));
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    final line = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, line);
    final dot = Paint()..color = lineColor;
    for (final point in points) {
      canvas.drawCircle(point, 4.5, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _ScoreChartPainter oldDelegate) =>
      scores != oldDelegate.scores || lineColor != oldDelegate.lineColor;
}

class WeakSpotsCard extends StatelessWidget {
  final List<Map<String, dynamic>> records;

  const WeakSpotsCard({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    final groups = DevSprintAnalytics.byCategory(records);
    final entries = groups.entries.where((e) => e.value.isNotEmpty).map((
      entry,
    ) {
      final avg = DevSprintAnalytics.averageScore(entry.value);
      return MapEntry(entry.key, avg);
    }).toList()..sort((a, b) => a.value.compareTo(b.value));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Needs attention',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            'Areas where recent scores leave room to grow.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            const _EmptyWidget(
              title: '',
              message: 'Your weaker areas will emerge after a few sprints.',
            )
          else
            ...entries
                .take(5)
                .map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        SizedBox(
                          width: 110,
                          child: LinearProgressIndicator(
                            value: entry.value / 100,
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 36,
                          child: Text(
                            '${entry.value.round()}',
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class RecentExploredCard extends StatelessWidget {
  final List<Map<String, dynamic>> records;

  const RecentExploredCard({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    final groups = DevSprintAnalytics.byLanguage(records);
    final entries = groups.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recently explored',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            'Stacks you have actually practiced.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            const _EmptyWidget(
              title: '',
              message: 'Your practiced stacks will appear here.',
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: entries
                  .take(8)
                  .map(
                    (entry) => Chip(
                      label: Text('${entry.key} · ${entry.value.length}'),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class DeveloperYearReviewCard extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  final int year;

  const DeveloperYearReviewCard({
    super.key,
    required this.records,
    required this.year,
  });

  @override
  Widget build(BuildContext context) {
    final yearRecords = records.where((r) {
      final date = DateTime.tryParse(r['completedAt'] as String? ?? '');
      return date?.year == year;
    }).toList();
    final passed = yearRecords.where((r) => r['success'] == true).length;
    final minutes = DevSprintAnalytics.totalFocusedMinutes(yearRecords);
    final avg = DevSprintAnalytics.averageScore(yearRecords);
    final languages = DevSprintAnalytics.byLanguage(yearRecords).length;
    final categories = DevSprintAnalytics.byCategory(yearRecords).length;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$year in review',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const Icon(Icons.auto_awesome_rounded),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  value: '${yearRecords.length}',
                  label: 'sprints',
                ),
              ),
              Expanded(
                child: _Metric(value: '$passed', label: 'passed'),
              ),
              Expanded(
                child: _Metric(value: '${minutes ~/ 60}h', label: 'focused'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            yearRecords.isEmpty
                ? 'Your first sprint will start the story.'
                : '$languages stacks · $categories practice areas · ${avg.round()} average score',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class DeveloperDnaCard extends StatelessWidget {
  final List<Map<String, dynamic>> records;

  const DeveloperDnaCard({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    final groups = DevSprintAnalytics.byCategory(records);
    final total = math.max(1, records.length);
    final dimensions = <String, double>{
      'Builder': _weight(groups, [
        'Engineering',
        'Backend & APIs',
        'Mobile Development',
        'UI / UX Engineering',
      ], total),
      'Debugger': _weight(groups, ['Debugging', 'Testing & Quality'], total),
      'Architect': _weight(groups, [
        'System Design',
        'Cloud & Distributed Systems',
        'OOP & Design',
      ], total),
      'Optimizer': _weight(groups, [
        'Databases',
        'Concurrency & Systems',
        'DevOps & Tooling',
      ], total),
    };
    final sorted = dimensions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Developer DNA',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            'A living snapshot of the kind of engineering you practice.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          ...sorted.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 82,
                    child: Text(
                      entry.key,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(child: LinearProgressIndicator(value: entry.value)),
                  const SizedBox(width: 10),
                  Text('${(entry.value * 100).round()}%'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _weight(
    Map<String, List<Map<String, dynamic>>> groups,
    List<String> keys,
    int total,
  ) {
    final count = keys.fold<int>(
      0,
      (sum, key) => sum + (groups[key]?.length ?? 0),
    );
    return (count / total).clamp(0.0, 1.0);
  }
}

class TodayActivityCard extends StatelessWidget {
  final List<Map<String, dynamic>> records;

  const TodayActivityCard({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = records.where((r) {
      final d = DateTime.tryParse(r['completedAt'] as String? ?? '');
      return d != null &&
          d.year == now.year &&
          d.month == now.month &&
          d.day == now.day;
    }).toList();
    final latest = today.isEmpty ? null : today.last;
    final cs = Theme.of(context).colorScheme;

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              today.isEmpty ? Icons.today_rounded : Icons.check_rounded,
              color: cs.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  latest == null
                      ? 'No sprint completed yet.'
                      : '${DevSprintAnalytics.task(latest)['title'] ?? 'Sprint'} · ${DevSprintAnalytics.score(latest)}/100',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (latest != null)
            Icon(
              latest['success'] == true
                  ? Icons.check_circle_rounded
                  : Icons.cancel_rounded,
              color: latest['success'] == true ? cs.primary : cs.error,
            ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String value;
  final String label;

  const _Metric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

class _EmptyWidget extends StatelessWidget {
  final String title;
  final String message;

  const _EmptyWidget({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (title.isNotEmpty) const SizedBox(height: 4),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
