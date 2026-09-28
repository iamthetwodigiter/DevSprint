import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'widget_bridge_service.dart';
part 'hive_service.g.dart';

class HiveService {
  static const taskBoxName = 'daily_tasks_box';
  static const historyBoxName = 'history_box';
  static const sessionBoxName = 'session_box';
  static const sprintBoxName = 'sprint_records_box';
  static const evaluationJobsBoxName = 'evaluation_jobs_box';

  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(taskBoxName);
    await Hive.openBox(historyBoxName);
    await Hive.openBox(sessionBoxName);
    await Hive.openBox(sprintBoxName);
    await Hive.openBox(evaluationJobsBoxName);
  }

  Future<void> saveCurrentTask(Map<String, dynamic> taskJson) async {
    final box = Hive.box(taskBoxName);
    await box.put('current_task', taskJson);
    await box.put('task_timestamp', DateTime.now().millisecondsSinceEpoch);
    await box.delete('current_task_cleared_at');
    await WidgetBridgeService.syncSprintActivity(
      getSprintRecords(),
      currentTask: taskJson,
    );
  }

  Map<String, dynamic>? getCurrentTask() {
    final raw = Hive.box(taskBoxName).get('current_task');
    if (raw is! Map) return null;
    return Map<String, dynamic>.from(raw);
  }

  Future<void> clearCurrentTask([String reason = '']) async {
    await Hive.box(taskBoxName).delete('current_task');
    await Hive.box(taskBoxName).delete('task_timestamp');
    await Hive.box(taskBoxName).put(
      'current_task_cleared_at',
      DateTime.now().toUtc().millisecondsSinceEpoch,
    );
    await WidgetBridgeService.syncSprintActivity(
      getSprintRecords(),
      currentTask: null,
    );
  }

  Map<String, dynamic> getCurrentTaskSyncState() {
    final box = Hive.box(taskBoxName);
    final task = getCurrentTask();
    final taskTimestamp = box.get('task_timestamp');
    final clearedAt = box.get('current_task_cleared_at');

    if (task != null) {
      return {
        'status': 'active',
        'updated_at': (taskTimestamp is int
                ? taskTimestamp
                : DateTime.now().millisecondsSinceEpoch)
            .toString(),
        'task': task,
      };
    }

    return {
      'status': 'cleared',
      'updated_at': (clearedAt is int ? clearedAt : 0).toString(),
      'task': null,
    };
  }

  Future<void> restoreCurrentTaskSyncState(Map<String, dynamic> syncState) async {
    final status = syncState['status'] as String? ?? 'cleared';
    final rawUpdated = syncState['updated_at']?.toString();
    final updatedAt = int.tryParse(rawUpdated ?? '') ??
        DateTime.now().millisecondsSinceEpoch;
    final box = Hive.box(taskBoxName);

    if (status == 'active' && syncState['task'] is Map) {
      await box.put(
        'current_task',
        Map<String, dynamic>.from(syncState['task'] as Map),
      );
      await box.put('task_timestamp', updatedAt);
      await box.delete('current_task_cleared_at');
    } else {
      await box.delete('current_task');
      await box.delete('task_timestamp');
      await box.put('current_task_cleared_at', updatedAt);
    }

    await WidgetBridgeService.syncSprintActivity(
      getSprintRecords(),
      currentTask: getCurrentTask(),
    );
  }

  Future<void> saveEvaluationJob(Map<String, dynamic> job) async {
    final id = job['id'] as String?;
    if (id == null || id.isEmpty) return;
    await Hive.box(evaluationJobsBoxName).put(id, job);
  }

  List<Map<String, dynamic>> getEvaluationJobs() {
    final box = Hive.box(evaluationJobsBoxName);
    final jobs = box.values
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    jobs.sort((a, b) {
      final ad = DateTime.tryParse(a['updated_at'] as String? ?? '') ?? DateTime(1970);
      final bd = DateTime.tryParse(b['updated_at'] as String? ?? '') ?? DateTime(1970);
      return bd.compareTo(ad);
    });
    return jobs;
  }

  Future<void> saveHistory(DateTime date, dynamic result) async {
    final key = _dateKey(date);
    await Hive.box(historyBoxName).put(key, result);
  }

  Map<String, dynamic> getHistory() {
    final box = Hive.box(historyBoxName);
    return {for (final key in box.keys) key.toString(): box.get(key)};
  }

  Future<void> saveSprintRecord(
    Map<String, dynamic> record, {
    bool markDirty = true,
    DateTime? syncedAt,
    bool updateWidgets = true,
  }) async {
    final id = record['id'] as String?;
    if (id == null || id.isEmpty) return;
    final copy = Map<String, dynamic>.from(record);
    final existing = getSprintRecord(id);
    final sync = existing?['sync'] is Map
        ? Map<String, dynamic>.from(existing!['sync'] as Map)
        : <String, dynamic>{};
    if (markDirty) {
      sync['status'] = 'pending';
      sync['local_updated_at'] = DateTime.now().toUtc().toIso8601String();
    } else if (syncedAt != null) {
      sync['status'] = 'synced';
      sync['last_synced_at'] = syncedAt.toUtc().toIso8601String();
      sync['local_updated_at'] ??= copy['completedAt'];
    }
    copy['sync'] = sync;
    await Hive.box(sprintBoxName).put(id, copy);
    final date = DateTime.tryParse(record['completedAt'] as String? ?? '');
    if (date != null) {
      await saveHistory(
        date,
        record['success'] == true ? record['score'] ?? 0 : 'Failed',
      );
    }

    if (updateWidgets) {
      await WidgetBridgeService.syncSprintActivity(
        getSprintRecords(),
        currentTask: getCurrentTask(),
      );
    }
  }

  List<Map<String, dynamic>> getSprintRecords() {
    final box = Hive.box(sprintBoxName);
    final records = box.values
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    records.sort((a, b) {
      final ad =
          DateTime.tryParse(a['completedAt'] as String? ?? '') ??
          DateTime(1970);
      final bd =
          DateTime.tryParse(b['completedAt'] as String? ?? '') ??
          DateTime(1970);
      return bd.compareTo(ad);
    });
    return records;
  }

  Map<String, dynamic>? getSprintRecord(String id) {
    final raw = Hive.box(sprintBoxName).get(id);
    if (raw is! Map) return null;
    return Map<String, dynamic>.from(raw);
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> saveSession({
    required String taskId,
    required DateTime startedAt,
    required int durationSeconds,
  }) async {
    await Hive.box(sessionBoxName).put('active', {
      'task_id': taskId,
      'started_at': startedAt.millisecondsSinceEpoch,
      'duration_seconds': durationSeconds,
    });
  }

  Map<String, dynamic>? getSession() {
    final raw = Hive.box(sessionBoxName).get('active');
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  }

  Future<void> clearSession() => Hive.box(sessionBoxName).delete('active');
}

@riverpod
HiveService hiveService(Ref ref) => HiveService();
