import 'dart:io';

import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/appearance_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/secure_storage_service.dart';
import '../../services/supabase_sync_service.dart';
import '../../providers/task_notifier.dart';
import '../../services/android_auto_sync_service.dart';
import '../../services/user_preferences_service.dart';
import '../widgets/app_card.dart';
import 'legal_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final preferences = UserPreferencesService();
  final focusController = TextEditingController();

  String language = UserPreferencesService.defaultLanguage;
  String level = UserPreferencesService.defaultLevel;
  String practiceType = UserPreferencesService.defaultPracticeType;
  String challengeStyle = UserPreferencesService.defaultChallengeStyle;
  bool loading = true;
  bool saving = false;
  bool syncing = false;
  bool autoSyncEnabled = false;
  int autoSyncIntervalHours = 4;
  DateTime? lastSyncAt;

  static const languages = [
    'Dart / Flutter',
    'Rust',
    'Python',
    'JavaScript',
    'TypeScript',
    'C',
    'C++',
    'Java',
    'Go',
    'Kotlin',
    'Swift',
    'SpringBoot',
    'Django',
    'Flask',
    'FastAPI',
    'Nodejs',
    'React',
    'NextJS',
  ];

  static const levels = ['Beginner', 'Intermediate', 'Advanced', 'Expert'];

  static const practiceModes = [
    'Engineering',
    'OOP & Design',
    'System Design',
    'Backend & APIs',
    'Databases',
    'Concurrency & Systems',
    'Debugging',
    'Testing & Quality',
    'Security',
    'DevOps & Tooling',
    'UI / UX Engineering',
    'Mobile Development',
    'Cloud & Distributed Systems',
    'Open Source / Code Reading',
  ];

  static const styles = ['Balanced', 'Deep Dive', 'Quick Win', 'Stretch'];

  static const fontOptions = [
    'Inter',
    'Ubuntu',
    'Manrope',
    'Space Grotesk',
    'Plus Jakarta Sans',
    'Fira Sans',
    'IBM Plex Sans',
  ];

  static const accentColors = <Color>[
    Color(0xFF6750A4),
    Color(0xFF006A6A),
    Color(0xFF0061A4),
    Color(0xFF8B5000),
    Color(0xFF9C4146),
    Color(0xFF4F5D95),
    Color(0xFF006E2C),
    Color(0xFF7A4FA3),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await preferences.load();
    focusController.text = data['focus'] ?? UserPreferencesService.defaultFocus;
    if (!mounted) return;
    setState(() {
      language = data['language'] ?? UserPreferencesService.defaultLanguage;
      level = data['level'] ?? UserPreferencesService.defaultLevel;
      practiceType =
          data['practiceType'] ?? UserPreferencesService.defaultPracticeType;
      challengeStyle =
          data['challengeStyle'] ??
          UserPreferencesService.defaultChallengeStyle;
      autoSyncEnabled = data['autoSyncEnabled'] == 'true';
      autoSyncIntervalHours =
          (int.tryParse(data['autoSyncIntervalHours'] ?? '') ?? 4)
              .clamp(1, 12)
              .toInt();
      lastSyncAt = data['lastSyncAt']?.isNotEmpty == true
          ? DateTime.tryParse(data['lastSyncAt']!)?.toLocal()
          : null;
      loading = false;
    });
  }

  Future<void> _save() async {
    if (saving) return;
    setState(() => saving = true);
    await preferences.saveDefaults(
      language: language,
      level: level,
      focus: focusController.text,
      practiceType: practiceType,
      challengeStyle: challengeStyle,
    );
    if (!mounted) return;
    setState(() => saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Challenge preferences saved.')),
    );
  }

  Future<void> _reset() async {
    await preferences.reset();
    await ref.read(appearanceProvider.notifier).setMode(ThemeMode.dark);
    await ref.read(appearanceProvider.notifier).setAmoled(false);
    await ref.read(appearanceProvider.notifier).setCustomAccentEnabled(false);
    await ref.read(appearanceProvider.notifier).setFont('Inter');
    focusController.text = UserPreferencesService.defaultFocus;
    if (!mounted) return;
    setState(() {
      language = UserPreferencesService.defaultLanguage;
      level = UserPreferencesService.defaultLevel;
      practiceType = UserPreferencesService.defaultPracticeType;
      challengeStyle = UserPreferencesService.defaultChallengeStyle;
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Personalisation reset.')));
  }

  Future<void> _changeApiKey() async {
    final controller = TextEditingController(
      text: await ref.read(secureStorageServiceProvider).getApiKey() ?? '',
    );
    if (!mounted) {
      controller.dispose();
      return;
    }
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Gemini API key'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Gemini API key',
            prefixIcon: Icon(Icons.key_rounded),
            helperText: 'Stored securely on this device.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return;
    await ref.read(secureStorageServiceProvider).saveApiKey(value);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('API key updated securely.')));
  }

  Future<void> _chooseFont() async {
    final current = ref.read(appearanceProvider).fontFamily;
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          children: [
            Text(
              'Choose interface font',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Code remains JetBrains Mono. This only changes the interface typography.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            RadioGroup<String>(
              groupValue: current,
              onChanged: (value) {
                if (value != null) {
                  Navigator.pop(context, value);
                }
              },
              child: Column(
                children: fontOptions
                    .map(
                      (font) => RadioListTile<String>(
                        value: font,
                        title: Text(
                          font,
                          style: TextStyle(
                            fontFamily: GoogleFonts.getFont(font).fontFamily,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
    if (selected != null) {
      await ref.read(appearanceProvider.notifier).setFont(selected);
    }
  }

  Future<void> _chooseAccent() async {
    var selected = ref.read(appearanceProvider).customAccent;
    final accepted = await ColorPicker(
      color: selected,
      onColorChanged: (color) => selected = color,
      heading: const Text('Custom accent'),
      subheading: const Text('Choose a Material 3 key color'),
      wheelSubheading: const Text('Fine tune the color'),
      showColorCode: true,
      pickersEnabled: const {
        ColorPickerType.primary: true,
        ColorPickerType.accent: true,
        ColorPickerType.wheel: true,
        ColorPickerType.custom: false,
        ColorPickerType.customSecondary: false,
        ColorPickerType.bw: false,
        ColorPickerType.both: false,
      },
      wheelDiameter: 180,
    ).showPickerDialog(context);
    if (accepted) {
      await ref.read(appearanceProvider.notifier).setAccent(selected);
    }
  }

  Future<void> _setAutoSync(bool enabled) async {
    if (!Platform.isAndroid) return;
    await preferences.saveAutoSync(
      enabled: enabled,
      intervalHours: autoSyncIntervalHours,
    );
    await AndroidAutoSyncService.configure(
      enabled: enabled,
      intervalHours: autoSyncIntervalHours,
    );
    if (mounted) setState(() => autoSyncEnabled = enabled);
  }

  Future<void> _setAutoSyncInterval(int hours) async {
    if (!Platform.isAndroid) return;
    await preferences.saveAutoSync(
      enabled: autoSyncEnabled,
      intervalHours: hours,
    );
    await AndroidAutoSyncService.configure(
      enabled: autoSyncEnabled,
      intervalHours: hours,
    );
    if (mounted) setState(() => autoSyncIntervalHours = hours);
  }

  String _syncTimeLabel() {
    final value = lastSyncAt;
    if (value == null) return 'Never synced on this device.';
    return 'Last synced ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(value))}';
  }

  Future<void> _sync() async {
    final auth = ref.read(authProvider);
    if (!auth.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supabase is not configured.')),
      );
      return;
    }

    if (!ref.read(authProvider).signedIn) {
      await _showAuthDialog();
      if (!mounted || !ref.read(authProvider).signedIn) return;
    }

    setState(() => syncing = true);
    try {
      final result = await ref.read(supabaseSyncServiceProvider).sync();
      ref.invalidate(taskProvider);
      if (!mounted) return;
      setState(() => lastSyncAt = result.timestamp);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'DevSprint synced with Supabase (${result.localSprints} local sprints backed up).',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Sync failed: $e')));
    } finally {
      if (mounted) setState(() => syncing = false);
    }
  }

  Future<void> _showAuthDialog() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final nameController = TextEditingController();
    bool isSignUp = false;
    String? authError;
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          return AlertDialog(
            title: Text(
              isSignUp ? 'Create Supabase account' : 'Sign in to Supabase',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isSignUp
                        ? 'Register with your email to sync your DevSprint progress across devices.'
                        : 'Sign in to access your synchronized sprints and preferences.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (authError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        authError!,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (isSignUp) ...[
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Your name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isSignUp
                            ? 'Already have an account? '
                            : "Don't have an account? ",
                        style: const TextStyle(fontSize: 13),
                      ),
                      GestureDetector(
                        onTap: isSubmitting
                            ? null
                            : () {
                                setDialogState(() {
                                  isSignUp = !isSignUp;
                                  authError = null;
                                });
                              },
                        child: Text(
                          isSignUp ? 'Sign In' : 'Sign Up',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final email = emailController.text.trim();
                        final password = passwordController.text;
                        final name = nameController.text.trim();

                        if (email.isEmpty || password.isEmpty) {
                          setDialogState(() {
                            authError = 'Please enter both email and password.';
                          });
                          return;
                        }

                        setDialogState(() {
                          isSubmitting = true;
                          authError = null;
                        });

                        try {
                          if (isSignUp) {
                            await ref
                                .read(authProvider.notifier)
                                .signUpWithEmail(
                                  email: email,
                                  password: password,
                                  name: name.isNotEmpty ? name : null,
                                );
                          } else {
                            await ref
                                .read(authProvider.notifier)
                                .signInWithEmail(
                                  email: email,
                                  password: password,
                                );
                          }

                          final authState = ref.read(authProvider);
                          if (authState.error != null) {
                            setDialogState(() {
                              authError = authState.error;
                              isSubmitting = false;
                            });
                          } else {
                            if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                          }
                        } catch (e) {
                          setDialogState(() {
                            authError = '$e';
                            isSubmitting = false;
                          });
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isSignUp ? 'Register' : 'Sign In'),
              ),
            ],
          );
        },
      ),
    );

    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
  }

  @override
  void dispose() {
    focusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appearance = ref.watch(appearanceProvider);
    final auth = ref.watch(authProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (loading) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      children: [
        Text(
          'Settings',
          style: theme.textTheme.displaySmall?.copyWith(
            fontFamily: GoogleFonts.ubuntu().fontFamily,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tune the parts of DevSprint that should adapt to you. The core sprint workspace stays the same.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        _sectionLabel(context, 'Challenge defaults'),
        const SizedBox(height: 10),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _dropdown(
                context,
                'Language / stack',
                Icons.code_rounded,
                language,
                languages,
                (v) => setState(() => language = v!),
              ),
              const SizedBox(height: 12),
              _dropdown(
                context,
                'Skill level',
                Icons.signal_cellular_alt_rounded,
                level,
                levels,
                (v) => setState(() => level = v!),
              ),
              const SizedBox(height: 12),
              _dropdown(
                context,
                'Practice mode',
                Icons.category_rounded,
                practiceType,
                practiceModes,
                (v) => setState(() => practiceType = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: focusController,
                decoration: const InputDecoration(
                  labelText: 'Focus area',
                  prefixIcon: Icon(Icons.track_changes_rounded),
                ),
              ),
              const SizedBox(height: 12),
              _dropdown(
                context,
                'Challenge personality',
                Icons.auto_awesome_rounded,
                challengeStyle,
                styles,
                (v) => setState(() => challengeStyle = v!),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _sectionLabel(context, 'Appearance'),
        const SizedBox(height: 10),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.brightness_6_outlined),
                title: const Text('Theme'),
                subtitle: Text(_themeLabel(appearance.mode)),
                trailing: SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.settings_suggest_outlined),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_outlined),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_outlined),
                    ),
                  ],
                  selected: {appearance.mode},
                  onSelectionChanged: (values) => ref
                      .read(appearanceProvider.notifier)
                      .setMode(values.first),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('AMOLED black'),
                subtitle: const Text('Use true black surfaces in dark mode.'),
                secondary: const Icon(Icons.brightness_1_outlined),
                value: appearance.amoled,
                onChanged: appearance.mode == ThemeMode.light
                    ? null
                    : (value) => ref
                          .read(appearanceProvider.notifier)
                          .setAmoled(value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Custom accent color'),
                subtitle: const Text(
                  'Override Android wallpaper colors with your own Material 3 key color.',
                ),
                secondary: CircleAvatar(
                  radius: 12,
                  backgroundColor: appearance.customAccent,
                ),
                value: appearance.useCustomAccent,
                onChanged: (value) => ref
                    .read(appearanceProvider.notifier)
                    .setCustomAccentEnabled(value),
              ),
              if (appearance.useCustomAccent) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: accentColors.map((color) {
                    final selected =
                        color.toARGB32() == appearance.customAccent.toARGB32();
                    return InkWell(
                      onTap: () => ref
                          .read(appearanceProvider.notifier)
                          .setAccent(color),
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          border: Border.all(
                            color: selected ? cs.onSurface : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: selected
                            ? Icon(
                                Icons.check,
                                color:
                                    ThemeData.estimateBrightnessForColor(
                                          color,
                                        ) ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Colors.black,
                                size: 19,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                OutlinedButton.icon(
                  onPressed: _chooseAccent,
                  icon: const Icon(Icons.colorize_rounded),
                  label: const Text('Open color wheel'),
                ),
              ],
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.text_fields_rounded),
                title: const Text('Typography'),
                subtitle: Text(
                  '${appearance.fontFamily} • JetBrains Mono for code',
                  style: TextStyle(
                    fontFamily: GoogleFonts.getFont(appearance.fontFamily)
                        .fontFamily,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _chooseFont,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _sectionLabel(context, 'Privacy & legal'),
        const SizedBox(height: 10),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy Policy'),
                subtitle: const Text(
                  'What DevSprint stores, sends, and syncs.',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LegalScreen.privacyPolicy(),
                  ),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cloud_sync_outlined),
                title: const Text('Data & Sync'),
                subtitle: const Text('Exactly what can leave this device.'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => LegalScreen.dataAndSync()),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _sectionLabel(context, 'Security & cross-platform sync'),
        const SizedBox(height: 10),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.key_rounded),
                title: const Text('Gemini API key'),
                subtitle: const Text(
                  'Stored using secure storage on this device.',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _changeApiKey,
              ),
              if (Platform.isAndroid) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.sync_rounded),
                  title: const Text('Automatic sync'),
                  subtitle: Text(
                    autoSyncEnabled
                        ? 'Android will sync every $autoSyncIntervalHours hours when a network connection is available.'
                        : 'Keep cloud data updated automatically on Android.',
                  ),
                  value: autoSyncEnabled,
                  onChanged: auth.signedIn ? _setAutoSync : null,
                ),
                if (autoSyncEnabled)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_rounded),
                    title: const Text('Sync interval'),
                    subtitle: Text(_syncTimeLabel()),
                    trailing: DropdownButton<int>(
                      value: autoSyncIntervalHours,
                      underline: const SizedBox.shrink(),
                      items: List.generate(12, (index) => index + 1)
                          .map(
                            (hours) => DropdownMenuItem<int>(
                              value: hours,
                              child: Text('$hours h'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) _setAutoSyncInterval(value);
                      },
                    ),
                  ),
              ],
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.sync_rounded),
                title: Text(
                  auth.signedIn ? 'Sync with Supabase' : 'Sign in to sync',
                ),
                subtitle: Text(
                  auth.signedIn
                      ? 'Backs up sprints, evaluations, preferences, and attached submission packages to Supabase.'
                      : 'Sign in to seamlessly sync across Linux, Android, and Windows.',
                ),
                trailing: syncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right_rounded),
                onTap: syncing ? null : _sync,
              ),
              if (auth.signedIn) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout_rounded),
                  title: const Text('Sign out'),
                  subtitle: Text(auth.email ?? 'Supabase account'),
                  onTap: () => ref.read(authProvider.notifier).signOut(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Note: Your Gemini API key is used only for creating and reviewing sprints. It is stored securely on your device and is never uploaded or stored online.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: saving ? null : _save,
            icon: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: const Text('Save challenge preferences'),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _reset,
          child: const Text('Reset personalisation'),
        ),
      ],
    );
  }

  String _themeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => 'Follow system',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };
  }

  Widget _sectionLabel(BuildContext context, String title) {
    return Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        fontFamily: GoogleFonts.ubuntu().fontFamily,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _dropdown(
    BuildContext context,
    String label,
    IconData icon,
    String value,
    List<String> values,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      items: values
          .map((v) => DropdownMenuItem(value: v, child: Text(v)))
          .toList(),
      onChanged: onChanged,
    );
  }
}
