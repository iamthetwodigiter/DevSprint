import 'dart:io';

import 'package:devsprint/services/secure_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/evaluation_jobs_provider.dart';
import '../../providers/task_notifier.dart';
import '../../services/user_preferences_service.dart';
import '../../services/widget_bridge_service.dart';
import '../../services/hive_service.dart';
import '../../services/supabase_sync_service.dart';
import '../widgets/activity_widgets.dart';
import '../widgets/app_card.dart';
import 'background_evaluations_screen.dart';
import 'focus_mode_screen.dart';
import 'onboarding_screen.dart';
import 'profile_screen.dart';
import 'progress_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const String defaultProfileName = 'Developer';

  int tab = 0;

  String language = 'Dart / Flutter';
  String level = 'Intermediate';
  String focus = 'Practical software engineering';
  String practiceType = 'Engineering';
  String challengeStyle = 'Balanced';

  String profileName = defaultProfileName;
  String profileImagePath = '';
  String developerNote = '';

  final preferences = UserPreferencesService();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadPreferences();

      final hive = ref.read(hiveServiceProvider);

      await WidgetBridgeService.syncSprintActivity(
        hive.getSprintRecords(),
        currentTask: hive.getCurrentTask(),
      );

      if (Platform.isLinux) {
        await _maybeOfferLinuxSync();
      }

      final key = await ref.read(secureStorageServiceProvider).getApiKey();

      if ((key == null || key.isEmpty) && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const OnboardingScreen(),
          ),
        );
      }
    });
  }

  Future<void> _maybeOfferLinuxSync() async {
    for (var attempt = 0; attempt < 8; attempt++) {
      if (!mounted) return;

      final authState = ref.read(authProvider);

      if (!authState.loading) break;

      await Future<void>.delayed(
        const Duration(milliseconds: 250),
      );
    }

    if (!mounted) return;

    final auth = ref.read(authProvider);

    if (!auth.signedIn) return;

    final shouldSync = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync DevSprint?'),
        content: const Text(
          'DevSprint is ready to sync your latest sprints and submissions with Supabase.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sync now'),
          ),
        ],
      ),
    );

    if (shouldSync == true && mounted) {
      try {
        final result = await ref.read(supabaseSyncServiceProvider).sync();

        ref.invalidate(taskProvider);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'DevSprint synced with Supabase (${result.localSprints} sprints).',
            ),
          ),
        );
      } catch (error) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not sync right now. You can try again from Settings.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadPreferences() async {
    final data = await preferences.load();

    if (!mounted) return;

    setState(() {
      language =
          data['language'] ?? UserPreferencesService.defaultLanguage;

      level =
          data['level'] ?? UserPreferencesService.defaultLevel;

      focus =
          data['focus'] ?? UserPreferencesService.defaultFocus;

      practiceType =
          data['practiceType'] ??
          UserPreferencesService.defaultPracticeType;

      challengeStyle =
          data['challengeStyle'] ??
          UserPreferencesService.defaultChallengeStyle;

      profileName =
          data['name'] ?? defaultProfileName;

      profileImagePath =
          data['profileImagePath'] ?? '';

      developerNote =
          data['bio'] ?? '';
    });
  }

  Future<void> generate() async {
    await ref
        .read(taskProvider.notifier)
        .generateDailyTask(
          language: language,
          skillLevel: level,
          focus: focus,
          practiceType: practiceType,
          challengeStyle: challengeStyle,
          developerNote: developerNote,
        );
  }

  @override
  Widget build(BuildContext context) {
    final taskState = ref.watch(taskProvider);
    final auth = ref.watch(authProvider);
    final evaluationJobs = ref.watch(evaluationJobsProvider);
    final runningEvaluations = evaluationJobs
        .where((job) => job['status'] == 'running')
        .length;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 24,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DevSprint',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            Text(
              'BUILD SOMETHING TODAY',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(
                    letterSpacing: 1.4,
                  ),
            ),
          ],
        ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'Background evaluations',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BackgroundEvaluationsScreen(),
                  ),
                ),
                icon: const Icon(Icons.pending_actions_rounded),
              ),
              if (runningEvaluations > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$runningEvaluations',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onError,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) {
          setState(() => tab = value);

          if (value == 0 || value == 2) {
            _loadPreferences();
          }
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard),
            label: 'Sprint',
          ),
          const NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Progress',
          ),
          NavigationDestination(
            icon: _profileNavIcon(
              context,
              auth,
              false,
            ),
            selectedIcon: _profileNavIcon(
              context,
              auth,
              true,
            ),
            label: 'Profile',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
      body: switch (tab) {
        0 => _buildSprint(context, taskState),
        1 => const ProgressScreen(),
        2 => const ProfileScreen(),
        _ => const SettingsScreen(),
      },
    );
  }

  Widget _profileNavIcon(
    BuildContext context,
    AuthState auth,
    bool selected,
  ) {
    final cs = Theme.of(context).colorScheme;

    final path = profileImagePath;

    final hasLocal =
        path.isNotEmpty && File(path).existsSync();

    final hasGoogle =
        auth.signedIn &&
        auth.photoUrl != null &&
        auth.photoUrl!.isNotEmpty;

    Widget avatar;

    if (hasGoogle) {
      avatar = CircleAvatar(
        radius: 12,
        backgroundImage: NetworkImage(
          auth.photoUrl!,
        ),
      );
    } else if (hasLocal) {
      avatar = CircleAvatar(
        radius: 12,
        backgroundImage: FileImage(
          File(path),
        ),
      );
    } else {
      final displayName =
          auth.signedIn &&
                  auth.name != null &&
                  auth.name!.trim().isNotEmpty
              ? auth.name!.trim()
              : (profileName.trim().isEmpty
                  ? defaultProfileName
                  : profileName.trim());

      avatar = CircleAvatar(
        radius: 12,
        backgroundColor: cs.primaryContainer,
        child: Text(
          displayName[0].toUpperCase(),
          style: TextStyle(
            color: cs.onPrimaryContainer,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    return Container(
      width: selected ? 34 : 30,
      height: selected ? 34 : 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: selected
            ? Border.all(
                color: cs.primary,
                width: 2,
              )
            : null,
      ),
      alignment: Alignment.center,
      child: avatar,
    );
  }

  Widget _buildSprint(
    BuildContext context,
    AsyncValue taskState,
  ) {
    return RefreshIndicator(
      onRefresh: generate,
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 20,
        ),
        children: [
          Text(
            'Today’s challenge',
            style: Theme.of(context)
                .textTheme
                .displaySmall
                ?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'A small block of deliberate pressure beats an endless backlog.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          taskState.when(
            loading: () {
              final notifier = ref.read(taskProvider.notifier);
              final model = notifier.generationModel;
              return AppCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Column(
                    children: [
                      const SizedBox(
                        width: 34,
                        height: 34,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        notifier.generationStep,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (model != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Gemini model: $model (${notifier.generationAttempt}/${notifier.generationTotalModels})',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
            error: (e, _) => AppCard(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Could not generate a sprint',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge,
                  ),
                  const SizedBox(height: 6),
                  _friendlyError(context, e),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: generate,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
            data: (task) => task == null
                ? _buildEmptyState(context)
                : _buildTaskCard(context, task),
          ),
          const SizedBox(height: 24),
          TodayActivityCard(
            records: ref
                .read(hiveServiceProvider)
                .getSprintRecords(),
          ),
          const SizedBox(height: 24),
          const SectionLabel(
            title: 'Sprint setup',
            action: 'before you generate',
          ),
          const SizedBox(height: 10),
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 20,
            ),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: language,
                  decoration: const InputDecoration(
                    labelText: 'Language / stack',
                    prefixIcon: Icon(
                      Icons.code_rounded,
                    ),
                  ),
                  items: const [
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
                  ]
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(v),
                        ),
                      )
                      .toList(),
                  onChanged: (v) =>
                      setState(() => language = v!),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: level,
                  decoration: const InputDecoration(
                    labelText: 'Skill level',
                    prefixIcon: Icon(
                      Icons.signal_cellular_alt_rounded,
                    ),
                  ),
                  items: const [
                    'Beginner',
                    'Intermediate',
                    'Advanced',
                    'Expert',
                  ]
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(v),
                        ),
                      )
                      .toList(),
                  onChanged: (v) =>
                      setState(() => level = v!),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: practiceType,
                  decoration: const InputDecoration(
                    labelText: 'Practice mode',
                    prefixIcon: Icon(
                      Icons.category_rounded,
                    ),
                  ),
                  items: const [
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
                  ]
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(v),
                        ),
                      )
                      .toList(),
                  onChanged: (v) =>
                      setState(() => practiceType = v!),
                ),
                const SizedBox(height: 14),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Focus area (optional)',
                    prefixIcon: Icon(
                      Icons.track_changes_rounded,
                    ),
                  ),
                  controller: TextEditingController(
                    text: focus,
                  ),
                  onChanged: (v) => focus = v,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: generate,
                    icon: const Icon(
                      Icons.auto_awesome_rounded,
                    ),
                    label: Text(
                      taskState.value == null
                          ? 'Generate today’s sprint'
                          : 'Generate a fresh sprint',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _friendlyError(
    BuildContext context,
    Object error,
  ) {
    final message = error.toString();
    final lower = message.toLowerCase();

    String title = 'Something went wrong';

    String body =
        'DevSprint could not create this sprint. Please try again.';

    if (lower.contains('api key is not configured')) {
      title = 'Gemini API key needed';

      body =
          'Add your Gemini API key in Settings before generating a sprint.';
    } else if (lower.contains('clientexception') ||
        lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network')) {
      title = 'Could not reach Gemini';

      body =
          'Check your internet connection and try again. If the problem continues, check your Gemini API key and model availability.';
    } else if (lower.contains('all configured gemini') ||
        lower.contains('quota') ||
        lower.contains('rate limit')) {
      title =
          'Gemini could not complete the request';

      body =
          'The configured Gemini models could not complete this request. Check your API key, quota, network connection, and model availability, then try again.';
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          body,
          style: Theme.of(context)
              .textTheme
              .bodyLarge,
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
  ) {
    final cs =
        Theme.of(context).colorScheme;

    return AppCard(
      child: Container(
        constraints: const BoxConstraints(
          minHeight: 200,
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons.rocket_launch_rounded,
              size: 50,
              color: cs.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No sprint loaded',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose your stack below and let the engine build a challenge around it.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: generate,
              icon: const Icon(
                Icons.bolt_rounded,
              ),
              label: const Text(
                'Generate sprint',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(
    BuildContext context,
    dynamic task,
  ) {
    final cs =
        Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  avatar: const Icon(
                    Icons.timer_outlined,
                    size: 17,
                  ),
                  label: Text(
                    '${task.deadlineMinutes} min',
                  ),
                ),
                Chip(
                  label: Text(task.difficulty),
                ),
                Chip(
                  label: Text(task.language),
                ),
                Chip(
                  label: Text(task.practiceType),
                ),
                if (task.modelUsed != null)
                  Chip(
                    avatar: const Icon(
                      Icons.auto_awesome,
                      size: 16,
                    ),
                    label: Text(
                      task.modelUsed!,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              task.title,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onPrimaryContainer,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              task.summary,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(
                    color: cs.onPrimaryContainer,
                  ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      FocusModeScreen(task: task),
                ),
              ),
              icon: const Icon(
                Icons.play_arrow_rounded,
              ),
              label: const Text(
                'Open challenge',
              ),
            ),
          ],
        ),
      ),
    );
  }
}