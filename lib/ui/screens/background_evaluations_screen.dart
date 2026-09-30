import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/evaluation_jobs_provider.dart';
import '../widgets/app_card.dart';
import '../widgets/app_page.dart';
import 'sprint_details_screen.dart';

class BackgroundEvaluationsScreen extends ConsumerWidget {
  const BackgroundEvaluationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(evaluationJobsProvider);
    final running = jobs.where((job) => job['status'] == 'running').length;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Evaluations')),
      body: AppPage(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          children: [
            const AppPageHeader(
              eyebrow: 'AI review',
              title: 'Evaluation queue',
              subtitle: 'Keep coding while DevSprint reviews your submissions.',
            ),
          const SizedBox(height: 4),
          Text(
            running == 0
                ? 'Your completed and interrupted evaluations stay here for review.'
                : '$running evaluation${running == 1 ? '' : 's'} running in the background.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          if (jobs.isEmpty)
            AppCard(
              child: Column(
                children: [
                  const Icon(Icons.inbox_outlined, size: 42),
                  const SizedBox(height: 12),
                  Text(
                    'No background evaluations yet',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Submit a sprint and DevSprint will evaluate it here without keeping you on the submission screen.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ...jobs.map((job) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _jobCard(context, ref, job),
                )),
          ],
        ),
      ),
    );
  }

  Widget _jobCard(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> job,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final status = job['status'] as String? ?? 'unknown';
    final task = Map<String, dynamic>.from(job['task'] as Map? ?? const {});
    final title = task['title'] as String? ?? 'Sprint evaluation';
    final model = job['model'] as String?;
    final step = job['step'] as String? ?? 'Waiting...';
    final error = job['error'] as String?;
    final sprintRecord = job['sprint_record'];

    final (IconData icon, Color color, String label) = switch (status) {
      'running' => (Icons.auto_awesome_rounded, cs.primary, 'Evaluating'),
      'completed' => (Icons.check_circle_rounded, cs.primary, 'Complete'),
      'failed' => (Icons.error_outline_rounded, cs.error, 'Failed'),
      'interrupted' => (Icons.pause_circle_outline_rounded, cs.error, 'Interrupted'),
      _ => (Icons.help_outline_rounded, cs.onSurfaceVariant, status),
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (model != null)
                Chip(
                  avatar: const Icon(Icons.auto_awesome, size: 15),
                  label: Text(model),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (status == 'running') ...[
            LinearProgressIndicator(
              value: null,
              minHeight: 5,
              borderRadius: BorderRadius.circular(5),
            ),
            const SizedBox(height: 10),
            Text(step),
          ] else if (error != null) ...[
            Text(
              error,
              style: TextStyle(color: cs.error),
            ),
          ] else
            Text(step),
          const SizedBox(height: 14),
          Row(
            children: [
              if (status == 'failed' || status == 'interrupted')
                OutlinedButton.icon(
                  onPressed: () => ref
                      .read(evaluationJobsProvider.notifier)
                      .retry(job['id'] as String),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              if (status == 'completed' && sprintRecord is Map)
                FilledButton.icon(
                  onPressed: () {
                    final record = ref
                        .read(evaluationJobsProvider.notifier)
                        .recordForJob(job['id'] as String);
                    if (record == null) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SprintDetailsScreen(record: record),
                      ),
                    );
                  },
                  icon: const Icon(Icons.rate_review_outlined),
                  label: const Text('View result'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
