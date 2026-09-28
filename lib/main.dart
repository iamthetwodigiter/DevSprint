import 'dart:io';

import 'package:devsprint/providers/appearance_provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_manager/window_manager.dart';

import 'services/hive_service.dart';
import 'services/android_auto_sync_service.dart';
import 'services/user_preferences_service.dart';
import 'ui/screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {}

  final WindowOptions windowOptions = const WindowOptions(
    size: Size(1200, 800),
    minimumSize: Size(800, 600),
    center: true,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.normal,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  await dotenv.load(fileName: '.env', isOptional: true);

  final hive = HiveService();
  await hive.init();

  await AndroidAutoSyncService.initialize();
  if (Platform.isAndroid) {
    final syncPreferences = UserPreferencesService();
    await AndroidAutoSyncService.configure(
      enabled: await syncPreferences.isAutoSyncEnabled(),
      intervalHours: await syncPreferences.autoSyncIntervalHours(),
    );
  }

  final supabaseUrl = dotenv.maybeGet('SUPABASE_URL') ?? '';
  final supabaseAnonKey = dotenv.maybeGet('SUPABASE_ANON_KEY') ?? '';

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: supabaseUrl.trim(),
        publishableKey: supabaseAnonKey.trim(),
      );
    } catch (e) {
      debugPrint('Supabase init skipped or failed: $e');
    }
  }

  runApp(
    ProviderScope(
      overrides: [hiveServiceProvider.overrideWithValue(hive)],
      child: const DevSprintApp(),
    ),
  );
}

class DevSprintApp extends ConsumerWidget {
  const DevSprintApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        ThemeData buildTheme(
          Brightness brightness,
          ColorScheme? dynamicScheme,
        ) {
          final useDynamic =
              !appearance.useCustomAccent && dynamicScheme != null;
          final seed = appearance.customAccent;

          ColorScheme scheme;
          if (useDynamic) {
            scheme = dynamicScheme;
          } else {
            scheme = ColorScheme.fromSeed(
              seedColor: seed,
              brightness: brightness,
            );
          }

          if (brightness == Brightness.dark && appearance.amoled) {
            scheme = scheme.copyWith(
              surface: Colors.black,
              surfaceDim: Colors.black,
              surfaceBright: const Color(0xFF181818),
              surfaceContainerLowest: Colors.black,
              surfaceContainerLow: const Color(0xFF050505),
              surfaceContainer: const Color(0xFF080808),
              surfaceContainerHigh: const Color(0xFF101010),
              surfaceContainerHighest: const Color(0xFF151515),
            );
          }

          final base = ThemeData(
            useMaterial3: true,
            brightness: brightness,
            colorScheme: scheme,
            fontFamily: GoogleFonts.getFont(appearance.fontFamily).fontFamily,
            visualDensity: VisualDensity.standard,
          );

          final textTheme = base.textTheme;
          final displayFont = GoogleFonts.ubuntu().fontFamily;
          final codeFont = GoogleFonts.jetBrainsMono().fontFamily;

          return base.copyWith(
            textTheme: textTheme.copyWith(
              displayLarge: textTheme.displayLarge?.copyWith(
                fontFamily: displayFont,
              ),
              displayMedium: textTheme.displayMedium?.copyWith(
                fontFamily: displayFont,
              ),
              displaySmall: textTheme.displaySmall?.copyWith(
                fontFamily: displayFont,
              ),
              headlineLarge: textTheme.headlineLarge?.copyWith(
                fontFamily: displayFont,
              ),
              headlineMedium: textTheme.headlineMedium?.copyWith(
                fontFamily: displayFont,
              ),
              headlineSmall: textTheme.headlineSmall?.copyWith(
                fontFamily: displayFont,
              ),
              bodySmall: textTheme.bodySmall?.copyWith(
                fontFamily: GoogleFonts.inter().fontFamily,
              ),
              bodyMedium: textTheme.bodyMedium?.copyWith(
                fontFamily: GoogleFonts.inter().fontFamily,
              ),
              bodyLarge: textTheme.bodyLarge?.copyWith(
                fontFamily: GoogleFonts.inter().fontFamily,
              ),
              labelSmall: textTheme.labelSmall?.copyWith(
                fontFamily: GoogleFonts.inter().fontFamily,
              ),
              labelMedium: textTheme.labelMedium?.copyWith(
                fontFamily: GoogleFonts.inter().fontFamily,
              ),
              labelLarge: textTheme.labelLarge?.copyWith(
                fontFamily: GoogleFonts.inter().fontFamily,
              ),
            ),
            scaffoldBackgroundColor: scheme.surface,
            appBarTheme: const AppBarTheme(
              centerTitle: false,
              scrolledUnderElevation: 0,
            ),
            cardTheme: CardThemeData(
              elevation: 0,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: scheme.primary, width: 2),
              ),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            navigationBarTheme: const NavigationBarThemeData(height: 72),
            extensions: [_DevSprintTypography(codeFontFamily: codeFont)],
          );
        }

        return MaterialApp(
          title: 'DevSprint',
          debugShowCheckedModeBanner: false,
          themeMode: appearance.mode,
          theme: buildTheme(Brightness.light, lightDynamic),
          darkTheme: buildTheme(Brightness.dark, darkDynamic),
          home: const HomeScreen(),
        );
      },
    );
  }
}

class _DevSprintTypography extends ThemeExtension<_DevSprintTypography> {
  final String? codeFontFamily;

  const _DevSprintTypography({required this.codeFontFamily});

  @override
  _DevSprintTypography copyWith({String? codeFontFamily}) {
    return _DevSprintTypography(
      codeFontFamily: codeFontFamily ?? this.codeFontFamily,
    );
  }

  @override
  _DevSprintTypography lerp(
    covariant ThemeExtension<_DevSprintTypography>? other,
    double t,
  ) {
    if (other is! _DevSprintTypography) return this;
    return _DevSprintTypography(
      codeFontFamily: t < 0.5 ? codeFontFamily : other.codeFontFamily,
    );
  }
}
