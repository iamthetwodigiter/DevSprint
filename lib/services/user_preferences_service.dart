import 'package:shared_preferences/shared_preferences.dart';

class UserPreferencesService {
  static const _nameKey = 'profile_name';
  static const _bioKey = 'profile_bio';
  static const _languageKey = 'preferred_language';
  static const _levelKey = 'preferred_level';
  static const _focusKey = 'preferred_focus';
  static const _practiceTypeKey = 'preferred_practice_type';
  static const _challengeStyleKey = 'challenge_style';
  static const _accountUidKey = 'account_uid';
  static const _accountNameKey = 'account_name';
  static const _accountEmailKey = 'account_email';
  static const _accountPhotoKey = 'account_photo';
  static const _profileImagePathKey = 'profile_image_path';
  static const _progressWidgetsKey = 'progress_widgets';
  static const _autoSyncEnabledKey = 'auto_sync_enabled';
  static const _autoSyncIntervalHoursKey = 'auto_sync_interval_hours';
  static const _lastSyncAtKey = 'last_sync_at';

  static const defaultLanguage = 'Dart / Flutter';
  static const defaultLevel = 'Intermediate';
  static const defaultFocus = 'Practical software engineering';
  static const defaultPracticeType = 'Engineering';
  static const defaultChallengeStyle = 'Balanced';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<Map<String, String>> load() async {
    final prefs = await _prefs;
    return {
      'name': prefs.getString(_nameKey) ?? '',
      'bio': prefs.getString(_bioKey) ?? '',
      'language': prefs.getString(_languageKey) ?? defaultLanguage,
      'level': prefs.getString(_levelKey) ?? defaultLevel,
      'focus': prefs.getString(_focusKey) ?? defaultFocus,
      'practiceType': prefs.getString(_practiceTypeKey) ?? defaultPracticeType,
      'challengeStyle':
          prefs.getString(_challengeStyleKey) ?? defaultChallengeStyle,
      'accountUid': prefs.getString(_accountUidKey) ?? '',
      'accountName': prefs.getString(_accountNameKey) ?? '',
      'accountEmail': prefs.getString(_accountEmailKey) ?? '',
      'accountPhoto': prefs.getString(_accountPhotoKey) ?? '',
      'profileImagePath': prefs.getString(_profileImagePathKey) ?? '',
      'autoSyncEnabled': (prefs.getBool(_autoSyncEnabledKey) ?? false).toString(),
      'autoSyncIntervalHours': (prefs.getInt(_autoSyncIntervalHoursKey) ?? 4).toString(),
      'lastSyncAt': prefs.getString(_lastSyncAtKey) ?? '',
    };
  }

  static const defaultProgressWidgets = <String>{};

  Future<Set<String>> loadProgressWidgets() async {
    final prefs = await _prefs;
    return prefs.getStringList(_progressWidgetsKey)?.toSet() ??
        {...defaultProgressWidgets};
  }


  Future<bool> isAutoSyncEnabled() async {
    final prefs = await _prefs;
    return prefs.getBool(_autoSyncEnabledKey) ?? false;
  }

  Future<int> autoSyncIntervalHours() async {
    final prefs = await _prefs;
    final value = prefs.getInt(_autoSyncIntervalHoursKey) ?? 4;
    return value.clamp(1, 12).toInt();
  }

  Future<void> saveAutoSync({required bool enabled, required int intervalHours}) async {
    final prefs = await _prefs;
    await Future.wait([
      prefs.setBool(_autoSyncEnabledKey, enabled),
      prefs.setInt(_autoSyncIntervalHoursKey, intervalHours.clamp(1, 12).toInt()),
    ]);
  }

  Future<void> saveLastSync(DateTime timestamp) async {
    final prefs = await _prefs;
    await prefs.setString(_lastSyncAtKey, timestamp.toUtc().toIso8601String());
  }

  Future<DateTime?> lastSyncAt() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_lastSyncAtKey);
    return raw == null || raw.isEmpty ? null : DateTime.tryParse(raw)?.toLocal();
  }

  Future<void> saveProgressWidgets(Set<String> widgets) async {
    final prefs = await _prefs;
    await prefs.setStringList(_progressWidgetsKey, widgets.toList()..sort());
  }

  Future<void> saveProfile({required String name, required String bio}) async {
    final prefs = await _prefs;
    await prefs.setString(_nameKey, name.trim());
    await prefs.setString(_bioKey, bio.trim());
  }

  Future<void> saveDefaults({
    required String language,
    required String level,
    required String focus,
    required String practiceType,
    required String challengeStyle,
  }) async {
    final prefs = await _prefs;
    await Future.wait([
      prefs.setString(_languageKey, language),
      prefs.setString(_levelKey, level),
      prefs.setString(_focusKey, focus.trim()),
      prefs.setString(_practiceTypeKey, practiceType),
      prefs.setString(_challengeStyleKey, challengeStyle),
    ]);
  }

  Future<void> saveAccount({
    required String uid,
    required String name,
    required String email,
    required String photoUrl,
  }) async {
    final prefs = await _prefs;
    await Future.wait([
      prefs.setString(_accountUidKey, uid),
      prefs.setString(_accountNameKey, name),
      prefs.setString(_accountEmailKey, email),
      prefs.setString(_accountPhotoKey, photoUrl),
    ]);
  }

  Future<void> clearAccount() async {
    final prefs = await _prefs;
    await Future.wait([
      prefs.remove(_accountUidKey),
      prefs.remove(_accountNameKey),
      prefs.remove(_accountEmailKey),
      prefs.remove(_accountPhotoKey),
    ]);
  }

  Future<void> saveProfileImagePath(String path) async {
    final prefs = await _prefs;
    await prefs.setString(_profileImagePathKey, path);
  }

  Future<void> clearProfileImagePath() async {
    final prefs = await _prefs;
    await prefs.remove(_profileImagePathKey);
  }

  Future<void> reset() async {
    final prefs = await _prefs;
    await Future.wait([
      prefs.remove(_nameKey),
      prefs.remove(_bioKey),
      prefs.remove(_languageKey),
      prefs.remove(_levelKey),
      prefs.remove(_focusKey),
      prefs.remove(_practiceTypeKey),
      prefs.remove(_challengeStyleKey),
      prefs.remove(_profileImagePathKey),
      prefs.remove(_progressWidgetsKey),
    ]);
  }
}
