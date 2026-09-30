import 'package:flutter/material.dart';
import '../widgets/app_card.dart';
import '../widgets/app_page.dart';

class LegalScreen extends StatelessWidget {
  final String title;
  final List<LegalSection> sections;

  const LegalScreen({super.key, required this.title, required this.sections});

  factory LegalScreen.privacyPolicy() => const LegalScreen(
    title: 'DevSprint Privacy Policy',
    sections: [
      LegalSection(
        'What DevSprint is',
        'DevSprint is a local-first coding-practice app. It creates timed software-engineering sprints, lets you submit code or project files, and uses Google Gemini to generate challenges and evaluate submissions. This policy explains exactly what DevSprint stores and what leaves your device.',
      ),
      LegalSection(
        'Data kept on your device',
        'DevSprint stores your profile, preferences, sprint history, generated tasks, evaluations, submitted code, attachment metadata, and submission packages locally so you can review previous work. Your Gemini API key is stored using the platform secure-storage facility.',
      ),
      LegalSection(
        'Gemini and your code',
        'When you generate a sprint, DevSprint sends your selected challenge preferences to Google Gemini. When you evaluate a submission, the task and relevant submission content are sent to the configured Gemini API. This can include inline code and source extracted from attached files or ZIP packages. DevSprint never sends your Gemini API key to Supabase.',
      ),
      LegalSection(
        'Supabase sync',
        'Cloud sync is optional and requires an account. When you explicitly sync, or when Android Automatic Sync is enabled, DevSprint can upload your profile, preferences, sprint history, evaluations, submitted source, and attachment metadata to the configured Supabase project. Submission ZIP packages are stored in the project’s private Supabase Storage bucket so old submissions can be restored on another device.',
      ),
      LegalSection(
        'Why submitted code is retained',
        'DevSprint intentionally retains submitted code and submission packages as part of your sprint history. This lets you open an old sprint later and review what you actually submitted, rather than only retaining its score.',
      ),
      LegalSection(
        'What you should not submit',
        'Do not attach passwords, private keys, access tokens, production credentials, confidential customer information, or other secrets. DevSprint is designed for development practice, not for handling secrets. Code sent to Gemini or synchronized to your Supabase project is subject to those services and their applicable policies.',
      ),
      LegalSection(
        'AI evaluation limits',
        'Gemini-generated tasks, explanations, scores, and evaluations can be incomplete, incorrect, inconsistent, or unsuitable for a particular engineering context. A passing score does not guarantee correctness, security, performance, maintainability, or production readiness. AI feedback is a learning aid, not a substitute for tests, code review, static analysis, or security review.',
      ),
      LegalSection(
        'Third-party services',
        'DevSprint can use Google Gemini for AI generation and evaluation and Supabase for authentication, synchronization, database storage, and private submission-file storage. Their availability, processing, limits, terms, and privacy practices are outside DevSprint’s control.',
      ),
      LegalSection(
        'Your choices',
        'You control whether you sign in and whether you use cloud sync. You can update or replace your Gemini API key from Settings. Local sprint history remains useful without cloud sync where the relevant feature does not require a network service.',
      ),
      LegalSection(
        'Deletion and changes',
        'Local data can be removed using the app’s available data controls. Cloud data is stored in the Supabase project configured for DevSprint and is subject to that project’s account and deletion procedures. This policy may be updated when DevSprint changes how it handles data; the policy bundled with a release describes that release.',
      ),
    ],
  );

  factory LegalScreen.dataAndSync() => const LegalScreen(
    title: 'Data & Sync',
    sections: [
      LegalSection(
        'Local-first',
        'Your sprint history is maintained locally first. Signing in does not by itself mean every action is immediately uploaded. Cloud transfer occurs when you manually synchronize or when Android Automatic Sync performs a scheduled synchronization.',
      ),
      LegalSection(
        'What Sync can contain',
        'A synchronized snapshot can contain profile information, challenge preferences, sprint metadata, task data, evaluation results, submitted code, extracted source/package text, and attachment names. The Gemini API key is excluded.',
      ),
      LegalSection(
        'Submission ZIPs',
        'Attached files are packaged into a ZIP for evaluation. When sync is enabled, DevSprint can upload that ZIP to the private Supabase Storage bucket configured for submission packages. The storage path is tied to the authenticated user and sprint record.',
      ),
      LegalSection(
        'Network and AI processing',
        'AI generation/evaluation and cloud synchronization require network access. If you work without those services, local functionality remains available where supported by the feature.',
      ),
      LegalSection(
        'Sensitive information',
        'Do not attach private keys, access tokens, passwords, credentials, proprietary customer data, or other sensitive material to a sprint unless you are comfortable sending it to the configured AI service and/or storing it in your configured Supabase project.',
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: AppPage(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          itemCount: sections.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final section = sections[index];
            return AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.heading,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    section.body,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class LegalSection {
  final String heading;
  final String body;

  const LegalSection(this.heading, this.body);
}
