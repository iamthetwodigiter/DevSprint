import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/app_card.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/secure_storage_service.dart';
import 'home_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final keyController = TextEditingController();
  int page = 0;

  Future<void> save() async {
    final key = keyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add your Gemini API key to continue.')),
      );
      return;
    }
    await ref.read(secureStorageServiceProvider).saveApiKey(key);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  void dispose() {
    keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final steps = [
      (
        Icons.bolt_rounded,
        'Focused coding sprints',
        'One practical challenge, one time box, one clear finish line.',
      ),
      (
        Icons.folder_zip_rounded,
        'Work with real code',
        'Submit individual files, project folders, or ZIP archives when the challenge needs them.',
      ),
      (
        Icons.insights_rounded,
        'Useful AI review',
        'Get feedback on correctness, clean code, modularity, and reusability after you ship.',
      ),
    ];
    final current = steps[page];

    Widget progress() => Row(
          children: List.generate(
            steps.length,
            (i) => Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: EdgeInsets.only(right: i == steps.length - 1 ? 0 : 6),
                height: 5,
                decoration: BoxDecoration(
                  color: i == page ? cs.primary : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        );

    Widget keyStep() => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connect Gemini',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your API key stays in secure storage on this device. DevSprint does not upload it to your sync account.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: keyController,
              obscureText: true,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Gemini API key',
                prefixIcon: Icon(Icons.key_rounded),
              ),
              onSubmitted: (_) => save(),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => launchUrl(
                Uri.parse('https://aistudio.google.com/app/apikey'),
              ),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Get a Gemini API key'),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: save,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Start using DevSprint'),
              ),
            ),
          ],
        );

    Widget stepIntro() => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(current.$1, color: cs.onPrimaryContainer, size: 27),
            ),
            const SizedBox(height: 24),
            Text(
              'DEVSPRINT',
              style: theme.textTheme.labelMedium?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              current.$2,
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              current.$3,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            progress(),
          ],
        );

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 900;
            final content = SizedBox(
              width: desktop && constraints.maxWidth > 1080 ? 1080 : constraints.maxWidth,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                child: desktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: stepIntro()),
                          const SizedBox(width: 48),
                          Expanded(
                            child: AppCard(
                              padding: const EdgeInsets.all(24),
                              child: page < steps.length - 1
                                  ? _introAction(context, theme, cs)
                                  : keyStep(),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          stepIntro(),
                          const SizedBox(height: 28),
                          AppCard(
                            padding: const EdgeInsets.all(20),
                            child: page < steps.length - 1
                                ? _introAction(context, theme, cs)
                                : keyStep(),
                          ),
                        ],
                      ),
                ),
              ),
            );
            return Center(child: content);
          },
        ),
      ),
    );
  }

  Widget _introAction(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What you can expect',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'DevSprint keeps the loop short: configure, build, submit, learn.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => setState(() => page++),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Continue'),
          ),
        ),
        if (page > 0)
          Center(
            child: TextButton(
              onPressed: () => setState(() => page--),
              child: const Text('Back'),
            ),
          ),
      ],
    );
  }

}
