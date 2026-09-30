import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/evaluation_notifier.dart';
import '../widgets/app_card.dart';
import '../widgets/app_page.dart';

String _friendlyError(Object error) {
  final message = error.toString().toLowerCase();
  if (message.contains('api key is not configured')) {
    return 'Your Gemini API key is not configured. Add it in Settings and try the evaluation again.';
  }
  if (message.contains('clientexception') ||
      message.contains('socketexception') ||
      message.contains('failed host lookup') ||
      message.contains('network')) {
    return 'DevSprint could not reach Gemini. Check your internet connection and try the evaluation again.';
  }
  if (message.contains('quota') || message.contains('rate limit')) {
    return 'Gemini rate limits or quota prevented the evaluation. Try again later.';
  }
  return 'DevSprint could not complete the evaluation. Please try again.';
}

class EvaluationScreen extends ConsumerWidget {
  const EvaluationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(evaluationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sprint review'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () =>
              Navigator.popUntil(context, (route) => route.isFirst),
        ),
      ),
      body: state.when(
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 18),
              Text('Reviewing your submission…'),
            ],
          ),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: AppCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 44),
                  const SizedBox(height: 12),
                  Text(
                    'Evaluation failed',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(_friendlyError(e), textAlign: TextAlign.center),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back to sprint'),
                  ),
                ],
              ),
            ),
          ),
        ),
        data: (evaluation) {
          if (evaluation == null) {
            return const Center(child: Text('No evaluation available.'));
          }
          return AppPage(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              children: [
                AppPageHeader(
                  eyebrow: 'Evaluation',
                  title: 'You shipped.',
                  subtitle: evaluation.summaryFeedback,
                ),
                const SizedBox(height: 4),
              AppCard(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 560;
                    final scoreView = SizedBox(
                      width: compact ? 92 : 116,
                      height: compact ? 92 : 116,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: evaluation.overallScore / 100,
                            strokeWidth: compact ? 8 : 10,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                          ),
                          Text(
                            '${evaluation.overallScore}',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    );
                    final details = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Overall score',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(evaluation.verdict),
                        const SizedBox(height: 10),
                        const Text('100 points across four engineering dimensions.'),
                      ],
                    );
                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [scoreView, const SizedBox(height: 16), details],
                      );
                    }
                    return Row(
                      children: [
                        scoreView,
                        const SizedBox(width: 22),
                        Expanded(child: details),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              _score(context, 'Correctness', evaluation.subScores.correctness),
              _score(context, 'Clean code', evaluation.subScores.cleanCode),
              _score(context, 'Modularity', evaluation.subScores.modularity),
              _score(context, 'Reusability', evaluation.subScores.reusability),
              const SizedBox(height: 14),
              _listCard(
                context,
                'What worked',
                Icons.thumb_up_alt_outlined,
                evaluation.keyStrengths,
              ),
              const SizedBox(height: 14),
              _listCard(
                context,
                'What to improve',
                Icons.build_outlined,
                evaluation.areasForImprovement,
              ),
              const SizedBox(height: 14),
              AppCard(
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Suggested refactoring'),
                  subtitle: const Text(
                    'A concrete next pass, not just a score.',
                  ),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SelectableText(evaluation.suggestedRefactoring),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () =>
                    Navigator.popUntil(context, (route) => route.isFirst),
                icon: const Icon(Icons.home_rounded),
                label: const Text('Back to dashboard'),
              ),
            ],
          ),
        );
        },
      ),
    );
  }

  Widget _score(BuildContext context, String label, int value) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            width: 120,
            child: LinearProgressIndicator(value: value / 25),
          ),
          const SizedBox(width: 12),
          Text(
            '$value/25',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _listCard(
    BuildContext context,
    String title,
    IconData icon,
    List<String> items,
  ) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: 10),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Text('Nothing recorded.')
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
