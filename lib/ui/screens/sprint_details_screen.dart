import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_highlight/themes/night-owl.dart';
import 'package:markdown_widget/markdown_widget.dart';

import '../widgets/app_card.dart';

class SprintDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> record;

  const SprintDetailsScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final success = record['success'] == true;
    final score = (record['score'] as num?)?.toInt() ?? 0;
    final task = Map<String, dynamic>.from(record['task'] ?? {});
    final evaluation = Map<String, dynamic>.from(record['evaluation'] ?? {});
    final submission = Map<String, dynamic>.from(record['submission'] ?? {});

    return Scaffold(
      appBar: AppBar(title: const Text('Sprint details')),
      body: DefaultTabController(
        length: 5,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: AppCard(
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 54,
                      decoration: BoxDecoration(
                        color: success ? cs.primary : cs.error,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task['title'] as String? ?? 'Sprint',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            success
                                ? 'Passed • $score/100'
                                : 'Failed • $score/100',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: success ? cs.primary : cs.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'Problem'),
                Tab(text: 'Solution'),
                Tab(text: 'Submission'),
                Tab(text: 'Evaluation'),
                Tab(text: 'Sprint info'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _problem(context, task),
                  _solution(context, submission),
                  _submissionDetails(context, submission),
                  _evaluation(context, evaluation),
                  _info(context, task, record),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _problem(BuildContext context, Map<String, dynamic> task) {
    final statement = task['problem_statement'] as String?;
    final markdown =
        statement == null || statement.trim().isEmpty
            ? 'No problem statement saved.'
            : statement;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: [
        AppCard(
          padding: EdgeInsets.zero,
          child: _buildProblemMarkdown(context, markdown),
        ),
      ],
    );
  }

  Widget _buildProblemMarkdown(BuildContext context, String markdown) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bodyStyle =
        theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurface,
          height: 1.6,
        ) ??
        TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 16,
          height: 1.6,
        );

    final baseConfig = isDark
        ? MarkdownConfig.darkConfig
        : MarkdownConfig.defaultConfig;

    final preConfig = isDark
        ? PreConfig.darkConfig.copy(
            theme: nightOwlTheme,
            decoration: BoxDecoration(
              color: const Color(0xFF11111B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
          )
        : const PreConfig().copy(
            theme: githubTheme,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
          );

    final config = baseConfig.copy(
      configs: [
        PConfig(textStyle: bodyStyle),
        H1Config(
          style: theme.textTheme.headlineMedium!.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        H2Config(
          style: theme.textTheme.headlineSmall!.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        H3Config(
          style: theme.textTheme.titleLarge!.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        H4Config(
          style: theme.textTheme.titleMedium!.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        H5Config(
          style: theme.textTheme.titleSmall!.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        H6Config(
          style: theme.textTheme.labelLarge!.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        isDark ? CodeConfig.darkConfig : const CodeConfig(),
        preConfig,
        LinkConfig(
          style: TextStyle(
            color: theme.colorScheme.primary,
            decoration: TextDecoration.underline,
          ),
        ),
        HrConfig(color: theme.dividerColor),
        TableConfig(
          headerStyle: bodyStyle.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );

    try {
      final widgets = MarkdownGenerator().buildWidgets(
        markdown,
        config: config,
      );

      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: widgets,
        ),
      );
    } catch (_) {
      return Padding(
        padding: const EdgeInsets.all(18),
        child: SelectableText(
          markdown,
          style: bodyStyle,
        ),
      );
    }
  }

  Widget _solution(BuildContext context, Map<String, dynamic> submission) {
    final code = submission['code'] as String? ?? '';
    final source = submission['source'] as String? ?? '';
    final solution = code.isNotEmpty ? code : source;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: [
        AppCard(
          padding: EdgeInsets.zero,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF11111B)
                  : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(24),
            ),
            child: SelectableText(
              solution.isEmpty ? 'No solution source was saved.' : solution,
              style: const TextStyle(fontFamily: 'JetBrains Mono', height: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _submissionDetails(
    BuildContext context,
    Map<String, dynamic> submission,
  ) {
    final files =
        (submission['files'] as List?)?.map((e) => '$e').toList() ?? const [];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Submitted files',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              if (files.isEmpty)
                const Text('Inline editor only.')
              else
                ...files.map(
                  (file) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.insert_drive_file_outlined),
                    title: Text(file),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AppCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.archive_outlined),
            title: const Text('Submission package'),
            subtitle: Text(
              submission['package_storage_path'] != null
                  ? 'Synced ZIP package is available on this device.'
                  : submission['package_path'] != null
                  ? 'ZIP package is stored locally with this sprint.'
                  : submission['package'] as String? ??
                        'No package metadata saved.',
              maxLines: 8,
              overflow: TextOverflow.fade,
            ),
          ),
        ),
      ],
    );
  }

  Widget _evaluation(BuildContext context, Map<String, dynamic> evaluation) {
    final strengths =
        (evaluation['key_strengths'] as List?)?.map((e) => '$e').toList() ??
        const [];
    final improvements =
        (evaluation['areas_for_improvement'] as List?)
            ?.map((e) => '$e')
            .toList() ??
        const [];
    final scores = Map<String, dynamic>.from(evaluation['sub_scores'] ?? {});
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: [
        AppCard(
          child: Row(
            children: [
              SizedBox(
                width: 92,
                height: 92,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value:
                          ((evaluation['overall_score'] as num?)?.toInt() ??
                              0) /
                          100,
                      strokeWidth: 8,
                    ),
                    Text(
                      '${evaluation['overall_score'] ?? 0}',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      evaluation['verdict'] as String? ?? 'No verdict',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(evaluation['summary_feedback'] as String? ?? ''),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _scoreCard(context, 'Correctness', scores['correctness']),
        _scoreCard(context, 'Clean code', scores['clean_code']),
        _scoreCard(context, 'Modularity', scores['modularity']),
        _scoreCard(context, 'Reusability', scores['reusability']),
        const SizedBox(height: 14),
        _bulletCard(context, 'What worked', strengths),
        const SizedBox(height: 14),
        _bulletCard(context, 'What to improve', improvements),
        const SizedBox(height: 14),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Suggested refactoring',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              SelectableText(
                evaluation['suggested_refactoring'] as String? ?? '',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _scoreCard(BuildContext context, String label, dynamic value) {
    final score = (value as num?)?.toInt() ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
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
              child: LinearProgressIndicator(value: score / 25),
            ),
            const SizedBox(width: 12),
            Text(
              '$score/25',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bulletCard(BuildContext context, String title, List<String> items) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            const Text('Nothing recorded.')
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
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

  Widget _info(
    BuildContext context,
    Map<String, dynamic> task,
    Map<String, dynamic> record,
  ) {
    final rows = {
      'Language': task['language'] ?? 'Unknown',
      'Difficulty': task['difficulty'] ?? 'Unknown',
      'Practice mode': task['practice_type'] ?? 'Engineering',
      'Deadline': '${task['deadline_minutes'] ?? 0} minutes',
      'Model': task['model_used'] ?? 'Unknown',
      'Completed': record['completedAt'] ?? 'Unknown',
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: [
        AppCard(
          child: Column(
            children: rows.entries
                .map(
                  (entry) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.key),
                    trailing: Text('${entry.value}'),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
