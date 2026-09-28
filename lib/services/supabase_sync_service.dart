import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'hive_service.dart';
import 'user_preferences_service.dart';

class SupabaseSyncResult {
  final int localSprints;
  final int remoteSprints;
  final DateTime timestamp;
  final int uploadedPackages;
  final int deletedPackages;

  const SupabaseSyncResult({
    required this.localSprints,
    required this.remoteSprints,
    required this.timestamp,
    this.uploadedPackages = 0,
    this.deletedPackages = 0,
  });
}

class SupabaseSyncService {
  static const submissionBucket = 'devsprint-submissions';

  final HiveService hive;
  final UserPreferencesService preferences;

  SupabaseSyncService(this.hive, this.preferences);

  bool get isReady {
    try {
      return Supabase.instance.client.auth.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  Future<SupabaseSyncResult> sync() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to sync your data.');
    }

    final response = await client
        .from('devsprint_sync')
        .select('snapshot, updated_at')
        .eq('user_id', user.id)
        .maybeSingle();

    final remoteSnapshot = response?['snapshot'] is Map
        ? Map<String, dynamic>.from(response!['snapshot'] as Map)
        : <String, dynamic>{};
    final rawRemoteRecords = (remoteSnapshot['sprints'] as List?) ?? const [];
    final remoteRecords = _latestRecords(rawRemoteRecords);

    await _mergeCurrentTask(remoteSnapshot['current_task_state']);
    await _mergeRemote(remoteRecords);

    final localRecords = _latestLocalRecords();
    final oldStoragePaths = _storagePaths(rawRemoteRecords);
    final prepared = await _prepareRecords(user.id, localRecords.values);
    final now = DateTime.now().toUtc();

    final mergedSnapshot = await _buildSnapshot(
      prepared.records,
      now,
      currentTaskState: hive.getCurrentTaskSyncState(),
    );

    await client.from('devsprint_sync').upsert({
      'user_id': user.id,
      'snapshot': mergedSnapshot,
      'updated_at': now.toIso8601String(),
    });

    final currentStoragePaths = _storagePaths(prepared.records);
    final obsolete = oldStoragePaths.difference(currentStoragePaths);
    var deletedPackages = 0;
    if (obsolete.isNotEmpty) {
      deletedPackages = await _deleteStorageObjects(user.id, obsolete);
    }

    await _deleteOlderLocalSubmissionPackages(localRecords.values);

    for (final record in prepared.records) {
      await hive.saveSprintRecord(
        record,
        markDirty: false,
        syncedAt: now,
        updateWidgets: false,
      );
    }
    await preferences.saveLastSync(now);

    return SupabaseSyncResult(
      localSprints: prepared.records.length,
      remoteSprints: remoteRecords.length,
      timestamp: now.toLocal(),
      uploadedPackages: prepared.uploadedPackages,
      deletedPackages: deletedPackages,
    );
  }

  Map<String, Map<String, dynamic>> _latestLocalRecords() {
    return _latestRecords(hive.getSprintRecords());
  }

  Map<String, Map<String, dynamic>> _latestRecords(Iterable<dynamic> raw) {
    final result = <String, Map<String, dynamic>>{};
    for (final item in raw) {
      if (item is! Map) continue;
      final record = _deepCopy(Map<String, dynamic>.from(item));
      final key = _sprintKey(record);
      final current = result[key];
      if (current == null || _recordDate(record).isAfter(_recordDate(current))) {
        result[key] = record;
      }
    }
    return result;
  }

  Future<void> _mergeCurrentTask(dynamic rawRemoteState) async {
    if (rawRemoteState is! Map) return;

    final remote = Map<String, dynamic>.from(rawRemoteState);
    final remoteUpdated = int.tryParse(remote['updated_at']?.toString() ?? '') ?? 0;
    final local = hive.getCurrentTaskSyncState();
    final localUpdated = int.tryParse(local['updated_at']?.toString() ?? '') ?? 0;

    if (remoteUpdated > localUpdated) {
      await hive.restoreCurrentTaskSyncState(remote);
    }
  }

  Future<void> _mergeRemote(
    Map<String, Map<String, dynamic>> remoteRecords,
  ) async {
    final localRecords = _latestLocalRecords();

    for (final entry in remoteRecords.entries) {
      final remote = entry.value;
      final local = localRecords[entry.key];
      if (local == null || _recordDate(remote).isAfter(_recordDate(local))) {
        final record = await _restoreSubmissionPackage(remote);
        await hive.saveSprintRecord(
          record,
          markDirty: false,
          syncedAt: _syncTimestamp(remote),
          updateWidgets: false,
        );
      }
    }
  }

  Future<_PreparedRecords> _prepareRecords(
    String userId,
    Iterable<Map<String, dynamic>> records,
  ) async {
    final prepared = <Map<String, dynamic>>[];
    var uploadedPackages = 0;

    for (final original in records) {
      final record = _deepCopy(original);
      final submission = _map(record['submission']);
      final localPath = submission['package_path'] as String?;
      final existingStoragePath = submission['package_storage_path'] as String?;

      if (localPath != null && localPath.isNotEmpty) {
        final file = File(localPath);
        if (await file.exists()) {
          final expectedStoragePath = _storagePath(userId, record);
          final storagePath = existingStoragePath?.isNotEmpty == true
              ? existingStoragePath!
              : expectedStoragePath;
          if (existingStoragePath != storagePath ||
              (existingStoragePath != null &&
                  existingStoragePath != expectedStoragePath)) {
            await _uploadSubmissionPackage(
              file: file,
              storagePath: storagePath,
            );
            uploadedPackages++;
          } else {
            // A previous sync already associated this local package with a
            // Storage object. Re-uploading is unnecessary unless the record
            // has a new revision and therefore a new storage path.
          }
          submission['package_storage_path'] = storagePath;
        }
      }

      submission.remove('package_path');
      record['submission'] = submission;
      prepared.add(record);
    }

    return _PreparedRecords(
      records: prepared,
      uploadedPackages: uploadedPackages,
    );
  }

  Future<Map<String, dynamic>> _buildSnapshot(
    Iterable<Map<String, dynamic>> records,
    DateTime now, {
    required Map<String, dynamic> currentTaskState,
  }) async {
    final prefs = await preferences.load();
    return {
      'schema': 3,
      'updated_at': now.toIso8601String(),
      'profile': {'name': prefs['name'] ?? '', 'bio': prefs['bio'] ?? ''},
      'challenge': {
        'language':
            prefs['language'] ?? UserPreferencesService.defaultLanguage,
        'level': prefs['level'] ?? UserPreferencesService.defaultLevel,
        'focus': prefs['focus'] ?? UserPreferencesService.defaultFocus,
        'practiceType':
            prefs['practiceType'] ?? UserPreferencesService.defaultPracticeType,
        'challengeStyle':
            prefs['challengeStyle'] ??
            UserPreferencesService.defaultChallengeStyle,
      },
      'sync': {
        'last_synced_at': now.toIso8601String(),
        'source': 'client',
      },
      'current_task_state': currentTaskState,
      'sprints': records.toList(),
    };
  }

  Future<Map<String, dynamic>> _restoreSubmissionPackage(
    Map<String, dynamic> record,
  ) async {
    final copy = _deepCopy(record);
    final submission = _map(copy['submission']);
    final storagePath = submission['package_storage_path'] as String?;

    if (storagePath != null && storagePath.isNotEmpty) {
      final localPath = submission['package_path'] as String?;
      if (localPath == null || !(await File(localPath).exists())) {
        try {
          final bytes = await Supabase.instance.client.storage
              .from(submissionBucket)
              .download(storagePath);
          final root = await getApplicationSupportDirectory();
          final directory = Directory('${root.path}/submissions');
          await directory.create(recursive: true);
          final filename = storagePath.split('/').last;
          final file = File('${directory.path}/$filename');
          await file.writeAsBytes(bytes, flush: true);
          submission['package_path'] = file.path;
        } on StorageException {
          // Source and evaluation data remain usable without the ZIP.
        }
      }
    }

    copy['submission'] = submission;
    return copy;
  }

  Future<void> _uploadSubmissionPackage({
    required File file,
    required String storagePath,
  }) async {
    try {
      await Supabase.instance.client.storage.from(submissionBucket).upload(
            storagePath,
            file,
            fileOptions: const FileOptions(
              contentType: 'application/zip',
              upsert: true,
            ),
          );
    } on StorageException catch (error) {
      throw StateError(
        'Could not sync a submission ZIP. Make sure the private '
        '"$submissionBucket" Storage bucket and its RLS policies are configured. '
        'Supabase reported: ${error.message}',
      );
    }
  }

  Future<int> _deleteStorageObjects(
    String userId,
    Set<String> paths,
  ) async {
    final safePaths = paths
        .where((path) => path.startsWith('$userId/'))
        .toList();
    if (safePaths.isEmpty) return 0;

    try {
      await Supabase.instance.client.storage
          .from(submissionBucket)
          .remove(safePaths);
      return safePaths.length;
    } on StorageException {
      // A failed cleanup must not invalidate a successfully synced snapshot.
      return 0;
    }
  }

  Future<void> _deleteOlderLocalSubmissionPackages(
    Iterable<Map<String, dynamic>> latestRecords,
  ) async {
    final latestIds = latestRecords.map((record) => record['id']).whereType<String>().toSet();
    final latestKeys = latestRecords.map(_sprintKey).toSet();

    for (final record in hive.getSprintRecords()) {
      final id = record['id'] as String?;
      if (id == null || latestIds.contains(id)) continue;
      if (!latestKeys.contains(_sprintKey(record))) continue;

      final path = _map(record['submission'])['package_path'] as String?;
      if (path == null || path.isEmpty) continue;
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {
        // Local cleanup is best effort. The synchronized source remains usable.
      }
    }
  }

  Set<String> _storagePaths(Iterable<dynamic> records) {
    return records
        .whereType<Map>()
        .map((record) => _map(record['submission'])['package_storage_path'])
        .whereType<String>()
        .where((path) => path.isNotEmpty)
        .toSet();
  }

  String _storagePath(String userId, Map<String, dynamic> record) {
    final sprintKey = _safeObjectName(_sprintKey(record));
    final submission = _map(record['submission']);
    final revision = _safeObjectName(
      '${submission['revision'] ?? submission['updated_at'] ?? record['completedAt'] ?? DateTime.now().microsecondsSinceEpoch}',
    );
    return '$userId/sprints/$sprintKey/$revision.zip';
  }

  String _sprintKey(Map<String, dynamic> record) {
    final explicit = record['sprint_key'] as String?;
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final task = _map(record['task']);
    final taskId = task['task_id'] as String?;
    if (taskId != null && taskId.isNotEmpty) return taskId;
    return record['id']?.toString() ?? 'unknown';
  }

  DateTime _recordDate(Map<String, dynamic> record) {
    final submission = _map(record['submission']);
    return DateTime.tryParse(
          submission['updated_at'] as String? ?? '',
        ) ??
        DateTime.tryParse(record['completedAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  DateTime _syncTimestamp(Map<String, dynamic> record) {
    final raw = _map(record['sync'])['last_synced_at'];
    return DateTime.tryParse(raw as String? ?? '') ?? _recordDate(record);
  }

  Map<String, dynamic> _deepCopy(Map<String, dynamic> value) {
    return Map<String, dynamic>.from(_copyValue(value) as Map);
  }

  dynamic _copyValue(dynamic value) {
    if (value is Map) {
      return value.map((key, value) => MapEntry(key, _copyValue(value)));
    }
    if (value is List) {
      return value.map(_copyValue).toList();
    }
    return value;
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _safeObjectName(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return cleaned.isEmpty ? 'submission' : cleaned;
  }
}

class _PreparedRecords {
  final List<Map<String, dynamic>> records;
  final int uploadedPackages;

  const _PreparedRecords({
    required this.records,
    required this.uploadedPackages,
  });
}

final supabaseSyncServiceProvider = Provider<SupabaseSyncService>((ref) {
  return SupabaseSyncService(
    ref.watch(hiveServiceProvider),
    UserPreferencesService(),
  );
});
