import 'dart:io';
import 'package:flutter/widgets.dart';
import 'dart:ui';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import 'hive_service.dart';
import 'supabase_sync_service.dart';
import 'user_preferences_service.dart';

class AndroidAutoSyncService {
  static const taskName = 'devsprint_auto_sync';
  static const uniqueTaskName = 'devsprint_auto_sync_periodic';

  static Future<void> initialize() async {
    if (!Platform.isAndroid) return;
    await Workmanager().initialize(callbackDispatcher);
  }

  static Future<void> configure({
    required bool enabled,
    required int intervalHours,
  }) async {
    if (!Platform.isAndroid) return;

    if (!enabled) {
      await Workmanager().cancelByUniqueName(uniqueTaskName);
      return;
    }

    await Workmanager().registerPeriodicTask(
      uniqueTaskName,
      taskName,
      frequency: Duration(hours: intervalHours.clamp(1, 12).toInt()),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
        requiresStorageNotLow: true,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      tag: 'devsprint-sync',
    );
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != AndroidAutoSyncService.taskName) return true;

    try {
      WidgetsFlutterBinding.ensureInitialized();
      DartPluginRegistrant.ensureInitialized();

      await dotenv.load(fileName: '.env', isOptional: true);

      final preferences = UserPreferencesService();
      if (!await preferences.isAutoSyncEnabled()) return true;

      final supabaseUrl = dotenv.maybeGet('SUPABASE_URL') ?? '';
      final supabaseKey = dotenv.maybeGet('SUPABASE_ANON_KEY') ?? '';
      if (supabaseUrl.isEmpty || supabaseKey.isEmpty) return true;

      await Supabase.initialize(
        url: supabaseUrl.trim(),
        publishableKey: supabaseKey.trim(),
      );

      if (Supabase.instance.client.auth.currentUser == null) return true;

      final hive = HiveService();
      await hive.init();

      await SupabaseSyncService(hive, preferences).sync();
      return true;
    } catch (error, stackTrace) {
      debugPrint('DevSprint background sync failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  });
}
