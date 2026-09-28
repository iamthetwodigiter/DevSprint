import 'dart:convert';
import 'package:flutter/services.dart';

class WidgetBridgeService {
  static const _channel = MethodChannel('app.thetwodigiter.devsprint/widget');

  static Future<void> syncSprintActivity(
    List<Map<String, dynamic>> records, {
    Map<String, dynamic>? currentTask,
  }) async {
    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final monthRecords = records.where((record) {
      final date = DateTime.tryParse(record['completedAt'] as String? ?? '');
      return date != null && date.year == now.year && date.month == now.month;
    }).toList();

    final days = <String, String>{};
    final intensities = <String, int>{};

    for (final record in monthRecords) {
      final date = DateTime.tryParse(record['completedAt'] as String? ?? '');
      if (date == null) {
        continue;
      }

      final key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final success = record['success'] == true;
      final current = days[key];

      if (current == null || success) {
        days[key] = success ? 'success' : 'failed';
      }

      final durationSeconds =
          (record['duration_seconds'] as num?)?.toInt() ?? 0;
      final durationMinutes = durationSeconds ~/ 60;
      intensities[key] = _intensity(durationMinutes);
    }

    final successful = records.where((e) => e['success'] == true).toList();
    final failed = records.where((e) => e['success'] != true).toList();

    final scored = records
        .map((e) => (e['score'] as num?)?.toDouble())
        .whereType<double>()
        .where((score) => score > 0)
        .toList();

    final averageScore = scored.isEmpty
        ? 0
        : (scored.reduce((a, b) => a + b) / scored.length).round();

    final focusedMinutes = records.fold<int>(
      0,
      (sum, record) =>
          sum + (((record['duration_seconds'] as num?)?.toInt() ?? 0) ~/ 60),
    );

    final practiceCounts = <String, int>{};
    for (final record in records) {
      final task = record['task'];
      if (task is Map) {
        final practice = task['practice_type'] as String? ?? 'Engineering';
        practiceCounts[practice] = (practiceCounts[practice] ?? 0) + 1;
      }
    }

    var mostPracticed = 'No activity yet';
    if (practiceCounts.isNotEmpty) {
      mostPracticed = practiceCounts.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
    }

    final today = DateTime(now.year, now.month, now.day);
    final todayRecords = records.where((record) {
      final date = DateTime.tryParse(record['completedAt'] as String? ?? '');
      return date != null && DateTime(date.year, date.month, date.day) == today;
    }).toList();

    var currentStreak = 0;
    for (var i = 0; i < 366; i++) {
      final day = today.subtract(Duration(days: i));
      final hasRun = records.any((record) {
        final date = DateTime.tryParse(record['completedAt'] as String? ?? '');
        return date != null && DateTime(date.year, date.month, date.day) == day;
      });
      if (!hasRun) break;
      currentStreak++;
    }

    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weekRecords = records.where((record) {
      final date = DateTime.tryParse(record['completedAt'] as String? ?? '');
      return date != null &&
          !date.isBefore(weekStart) &&
          date.isBefore(weekStart.add(const Duration(days: 7)));
    }).toList();

    final skillMap = <String, int>{};
    for (final entry in practiceCounts.entries) {
      skillMap[entry.key] = entry.value;
    }

    final state = <String, dynamic>{
      'month': monthKey,
      'completed': successful.length,
      'failed': failed.length,
      'focusedMinutes': focusedMinutes,
      'averageScore': averageScore,
      'mostPracticed': mostPracticed,
      'todayCompleted': todayRecords.where((e) => e['success'] == true).length,
      'todayFailed': todayRecords.where((e) => e['success'] != true).length,
      'todayMinutes': todayRecords.fold<int>(
        0,
        (sum, e) =>
            sum + (((e['duration_seconds'] as num?)?.toInt() ?? 0) ~/ 60),
      ),
      'currentStreak': currentStreak,
      'weekCompleted': weekRecords.where((e) => e['success'] == true).length,
      'weekMinutes': weekRecords.fold<int>(
        0,
        (sum, e) =>
            sum + (((e['duration_seconds'] as num?)?.toInt() ?? 0) ~/ 60),
      ),
      'skills': skillMap,
      'nextSprintTitle':
          currentTask?['title']?.toString() ?? 'No active sprint',
      'nextSprintLanguage': currentTask?['language']?.toString() ?? '',
      'nextSprintDeadline': currentTask?['deadline_minutes']?.toString() ?? '',
      'nextSprintPractice': currentTask?['practice_type']?.toString() ?? '',
      'days': {
        ...days,
        for (final entry in intensities.entries)
          '${entry.key}_intensity': entry.value,
      },
    };

    try {
      await _channel.invokeMethod<void>('updateWidget', {
        'state': jsonEncode(state),
      });
    } on MissingPluginException {
      // Native home-screen widgets only exist on Android.
    } on PlatformException {
      // A widget update should never break the Flutter app.
    }
  }

  static int _intensity(int minutes) {
    if (minutes >= 90) return 4;
    if (minutes >= 60) return 3;
    if (minutes >= 30) return 2;
    return 1;
  }
}
