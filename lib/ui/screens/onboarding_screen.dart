import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final steps = [
      (
        Icons.bolt_rounded,
        'One focused sprint.',
        'A practical coding challenge, a hard deadline, and one clear finish line.',
      ),
      (
        Icons.folder_zip_rounded,
        'Real projects, not toy answers.',
        'Attach one file, a whole folder worth of files, or an existing ZIP when the task gets serious.',
      ),
      (
        Icons.insights_rounded,
        'Learn from the result.',
        'DevSprint reviews correctness, readability, architecture and reusability after you submit.',
      ),
    ];
    final current = steps[page];

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(current.$1, size: 54, color: cs.primary),
                  const SizedBox(height: 28),
                  Text(
                    'DevSprint',
                    style: Theme.of(context).textTheme.displaySmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    current.$2,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    current.$3,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      steps.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 6,
                        width: i == page ? 32 : 8,
                        decoration: BoxDecoration(
                          color: i == page ? cs.primary : cs.outlineVariant,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 42),
                  if (page < steps.length - 1)
                    FilledButton(
                      onPressed: () => setState(() => page++),
                      child: const Text('Continue'),
                    )
                  else ...[
                    TextField(
                      controller: keyController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Gemini API key',
                        prefixIcon: Icon(Icons.key_rounded),
                        helperText: 'Stored in secure storage on this device.',
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse('https://aistudio.google.com/app/apikey'),
                      ),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Get an API key'),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: save,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('Enter DevSprint'),
                    ),
                  ],
                  const SizedBox(height: 18),
                  if (page > 0)
                    TextButton(
                      onPressed: () => setState(() => page--),
                      child: const Text('Back'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
