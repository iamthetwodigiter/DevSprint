import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_highlight/themes/night-owl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:flutter_highlight/themes/github.dart';
import '../../models/task_model.dart';
import '../../providers/evaluation_jobs_provider.dart';
import '../../providers/task_notifier.dart';
import '../../services/file_package_service.dart';
import '../../services/hive_service.dart';
import '../widgets/app_card.dart';

class FocusModeScreen extends ConsumerStatefulWidget {
  final TaskModel task;

  const FocusModeScreen({super.key, required this.task});

  @override
  ConsumerState<FocusModeScreen> createState() => _FocusModeScreenState();
}

class _FocusModeScreenState extends ConsumerState<FocusModeScreen> {
  Timer? timer;

  late int remaining;

  bool started = false;

  bool submitting = false;
  final codeController = TextEditingController();

  final List<SelectedSourceFile> attachments = [];

  @override
  void initState() {
    super.initState();

    remaining = widget.task.deadlineMinutes * 60;
  }

  @override
  void dispose() {
    timer?.cancel();

    codeController.dispose();

    super.dispose();
  }

  void start() {
    setState(() => started = true);

    final now = DateTime.now();

    ref
        .read(hiveServiceProvider)
        .saveSession(
          taskId: widget.task.taskId,

          startedAt: now,

          durationSeconds: remaining,
        );

    _startTimer();
  }

  void _startTimer() {
    timer?.cancel();
    if (remaining <= 0) return;
    timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (remaining <= 0) {
        timer?.cancel();
        await submit();
      } else if (mounted && !submitting) {
        setState(() => remaining--);
      }
    });
  }

  String get time {
    final h = remaining ~/ 3600;

    final m = (remaining % 3600) ~/ 60;

    final s = remaining % 60;

    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }

    return '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  Future<void> addFiles() async {
    final files = await ref.read(filePackageServiceProvider).pickFiles();

    if (files.isNotEmpty) {
      setState(() => attachments.addAll(files));
    }
  }

  Future<void> addZip() async {
    final zip = await ref.read(filePackageServiceProvider).pickZip();
    if (zip != null) {
      setState(() => attachments.add(zip));
    }
  }

  Future<void> submit() async {
    if (submitting) return;
    setState(() => submitting = true);
    timer?.cancel();

    try {
      String packageInfo;
      String sourceText = '';
      String? packagePath;

      if (attachments.isNotEmpty) {
        final service = ref.read(filePackageServiceProvider);
        final zip = await service.createZip(attachments);
        final source = await service.buildEvaluationSource(attachments);
        sourceText = source;
        packagePath = zip.path;
        packageInfo = 'ZIP submission package created.\n\n$source';
      } else {
        final inlineCode = codeController.text;
        packageInfo = inlineCode.length > 160000
            ? 'Inline submission only.\nCode:\n${inlineCode.substring(0, 160000)}'
            : 'Inline submission only.\nCode:\n$inlineCode';
      }

      final now = DateTime.now();
      final recordId = '${widget.task.taskId}_${now.microsecondsSinceEpoch}';
      final sprintRecord = <String, dynamic>{
        'id': recordId,
        'completedAt': now.toIso8601String(),
        'sprint_key': widget.task.taskId,
        'success': false,
        'score': 0,
        'duration_seconds': (widget.task.deadlineMinutes * 60 - remaining)
            .clamp(0, widget.task.deadlineMinutes * 60),
        'task': widget.task.toJson(),
        'evaluation_status': 'evaluating',
        'submission': {
          'code': codeController.text,
          'source': sourceText,
          'files': attachments.map((file) => file.name).toList(),
          'package': packageInfo.length > 180000
              ? packageInfo.substring(0, 180000)
              : packageInfo,
          'package_path': packagePath,
          'updated_at': now.toUtc().toIso8601String(),
          'revision': now.microsecondsSinceEpoch.toString(),
        },
      };

      await ref.read(evaluationJobsProvider.notifier).startEvaluation(
            jobId: recordId,
            task: widget.task,
            userCode: codeController.text,
            submissionPackage: packageInfo,
            sprintRecord: sprintRecord,
          );

      await ref.read(hiveServiceProvider).clearSession();
      await ref.read(taskProvider.notifier).cancelCurrentTask('Submitted');

      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not prepare the submission. ${error.toString().replaceFirst('Exception: ', '')}',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
      if (remaining > 0) _startTimer();
    }
  }

  Future<void> giveUp() async {
    timer?.cancel();
    final now = DateTime.now();
    String? packagePath;
    if (attachments.isNotEmpty) {
      try {
        packagePath =
            (await ref.read(filePackageServiceProvider).createZip(attachments))
                .path;
      } catch (_) {
        packagePath = null;
      }
    }

    await ref.read(hiveServiceProvider).saveSprintRecord({
      'id': '${widget.task.taskId}_${now.microsecondsSinceEpoch}',
      'completedAt': now.toIso8601String(),
      'sprint_key': widget.task.taskId,
      'success': false,
      'score': 0,
      'duration_seconds': (widget.task.deadlineMinutes * 60 - remaining).clamp(
        0,
        widget.task.deadlineMinutes * 60,
      ),
      'task': widget.task.toJson(),
      'evaluation': {
        'overall_score': 0,
        'verdict': 'FAILED',
        'summary_feedback': 'Sprint abandoned before submission.',
      },
      'submission': {
        'code': codeController.text,
        'files': attachments.map((file) => file.name).toList(),
        'package': 'Sprint abandoned before submission.',
        'package_path': packagePath,
        'updated_at': now.toUtc().toIso8601String(),
        'revision': now.microsecondsSinceEpoch.toString(),
      },
    });
    await ref.read(hiveServiceProvider).clearSession();
    await ref.read(taskProvider.notifier).cancelCurrentTask('Failed (Gave Up)');
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Widget _buildMarkdown(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bodyStyle =
        theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface,
          height: 1.55,
        ) ??
        TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 14,
          height: 1.55,
        );

    final baseConfig = isDark
        ? MarkdownConfig.darkConfig
        : MarkdownConfig.defaultConfig;

    final preConfig = isDark
        ? PreConfig.darkConfig.copy(
            theme: nightOwlTheme,
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.onPrimaryContainer),
              borderRadius: BorderRadius.circular(12),
            ),
          )
        : const PreConfig().copy(theme: githubTheme);

    final config = baseConfig.copy(
      configs: [
        PConfig(textStyle: bodyStyle),

        H1Config(
          style: theme.textTheme.headlineMedium!.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),

        H2Config(
          style: theme.textTheme.headlineSmall!.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),

        H3Config(
          style: theme.textTheme.titleLarge!.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
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
          headerStyle: bodyStyle.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );

    try {
      final markdownWidgets = MarkdownGenerator().buildWidgets(
        widget.task.problemStatement,
        config: config,
      );

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: markdownWidgets,
        ),
      );
    } catch (e) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        child: SelectableText(widget.task.problemStatement, style: bodyStyle),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !started,

      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && started) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Finish or give up the active sprint first.'),
            ),
          );
        }
      },

      child: Scaffold(
        appBar: AppBar(
          title: Text(started ? 'Focus mode' : 'Challenge brief'),

          leading: started ? null : const BackButton(),

          actions: [
            if (started)
              Padding(
                padding: const EdgeInsets.only(right: 18),

                child: Center(
                  child: Text(
                    time,

                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,

                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
          ],
        ),

        body: started ? _editor(context) : _brief(context),
      ),
    );
  }

  Widget _brief(BuildContext context) {
    final theme = Theme.of(context);

    final cs = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),

      children: [
        Wrap(
          spacing: 8,
          children: [
            Chip(
              avatar: const Icon(Icons.signal_cellular_alt_rounded, size: 17),
              label: Text(widget.task.difficulty),
            ),
            Chip(
              avatar: const Icon(Icons.code_rounded, size: 17),
              label: Text(widget.task.language),
            ),
            Chip(
              avatar: const Icon(Icons.category_rounded, size: 17),
              label: Text(widget.task.practiceType),
            ),
            Chip(
              avatar: const Icon(Icons.schedule_rounded, size: 17),
              label: Text('${widget.task.deadlineMinutes} minutes'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (widget.task.modelUsed != null)
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 15, color: cs.primary),

              const SizedBox(width: 6),

              Text(
                'Generated with ${widget.task.modelUsed}',

                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.primary,

                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

        const SizedBox(height: 10),

        Text(
          widget.task.title,

          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,

            height: 1.05,
          ),
        ),

        const SizedBox(height: 12),

        Text(
          widget.task.summary,

          style: theme.textTheme.titleMedium?.copyWith(
            color: cs.onSurfaceVariant,

            height: 1.45,
          ),
        ),

        if (widget.task.supportingImages.isNotEmpty) ...[
          const SizedBox(height: 18),
          AppCard(
            padding: EdgeInsets.zero,
            child: SizedBox(
              height: 190,
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                scrollDirection: Axis.horizontal,
                itemCount: widget.task.supportingImages.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        widget.task.supportingImages[index],
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) =>
                            progress == null
                            ? child
                            : const Center(child: CircularProgressIndicator()),
                        errorBuilder: (_, _, _) => Container(
                          color: cs.surfaceContainerHighest,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],

        const SizedBox(height: 24),

        AppCard(
          padding: EdgeInsets.zero,

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            mainAxisSize: MainAxisSize.min,

            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),

                child: Row(
                  children: [
                    Container(
                      width: 34,

                      height: 34,

                      decoration: BoxDecoration(
                        color: cs.primaryContainer,

                        borderRadius: BorderRadius.circular(10),
                      ),

                      child: Icon(
                        Icons.description_rounded,

                        size: 19,

                        color: cs.onPrimaryContainer,
                      ),
                    ),

                    const SizedBox(width: 12),

                    Text(
                      'The problem',

                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: _buildMarkdown(context),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        if (widget.task.constraints.isNotEmpty)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Row(
                  children: [
                    Icon(Icons.rule_rounded, color: cs.primary, size: 21),

                    const SizedBox(width: 10),

                    Text(
                      'Constraints',

                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                ...widget.task.constraints.map(
                  (constraint) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.check_circle_rounded,
                            size: 19,
                            color: cs.primary,
                          ),
                        ),

                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            constraint,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),

        if (widget.task.sampleCases.isNotEmpty)
          AppCard(
            padding: EdgeInsets.zero,

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),

                  child: Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,

                        color: cs.primary,

                        size: 21,
                      ),

                      const SizedBox(width: 10),

                      Text(
                        'Examples',

                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                ...widget.task.sampleCases.map(
                  (sample) => ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 20),

                    childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),

                    shape: const Border(),

                    collapsedShape: const Border(),

                    title: Text(
                      sample.input,

                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),

                      child: Text('Expected: ${sample.output}'),
                    ),

                    children: [
                      Align(
                        alignment: Alignment.centerLeft,

                        child: Text(
                          sample.explanation,

                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,

                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 28),

        FilledButton.icon(
          onPressed: start,

          icon: const Icon(Icons.play_arrow_rounded),

          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),

            child: Text('Start the sprint'),
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'The timer starts only after you press this button. '
          'Prepare first, then commit.',

          textAlign: TextAlign.center,

          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _editor(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;

              final brief = AppCard(
                child: ListView(
                  children: [
                    if (widget.task.modelUsed != null)
                      Text(
                        'Generated with ${widget.task.modelUsed}',

                        style: Theme.of(context).textTheme.labelMedium,
                      ),

                    const SizedBox(height: 8),

                    Text(
                      widget.task.title,

                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),

                    const SizedBox(height: 8),

                    Text(widget.task.summary),

                    const SizedBox(height: 16),

                    Text(
                      'Requirements',

                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),

                    const SizedBox(height: 8),

                    ...widget.task.constraints.map(
                      (constraint) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),

                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [
                            const Text('•  '),

                            Expanded(child: Text(constraint)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );

              final workspace = AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                      child: Row(
                        children: [
                          const Icon(Icons.code_rounded, size: 19),
                          const SizedBox(width: 8),
                          Text(
                            'Submission',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: submitting ? null : addFiles,
                            tooltip: 'Attach files',
                            icon: const Icon(Icons.attach_file_rounded),
                          ),
                          IconButton(
                            onPressed: submitting ? null : addZip,
                            tooltip: 'Attach ZIP',
                            icon: const Icon(Icons.folder_zip_rounded),
                          ),
                        ],
                      ),
                    ),

                    if (attachments.isNotEmpty)
                      SizedBox(
                        height: 58,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: attachments.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (_, i) => InputChip(
                            avatar: const Icon(
                              Icons.description_outlined,
                              size: 17,
                            ),
                            label: Text(attachments[i].name),
                            onDeleted: submitting ? null : () => setState(() => attachments.removeAt(i)),
                          ),
                        ),
                      ),

                    Expanded(
                      child: TextField(
                        controller: codeController,
                        readOnly: submitting,
                        expands: true,
                        maxLines: null,
                        minLines: null,
                        textAlignVertical: TextAlignVertical.top,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 14,
                          height: 1.45,
                        ),
                        decoration: const InputDecoration(
                          hintText:
                              '// Start writing here...\n'
                              '// Or attach your project files above.',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(18),
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          OutlinedButton(
                            onPressed: submitting ? null : giveUp,
                            child: Text(submitting ? 'Preparing...' : 'Give up'),
                          ),
                          const Spacer(),
                          FilledButton.icon(
                            onPressed: submitting ? null : submit,
                            icon: submitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded),
                            label: Text(submitting ? 'Submitting...' : 'Submit sprint'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );

              return Padding(
                padding: const EdgeInsets.all(16),

                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,

                        children: [
                          SizedBox(width: 340, child: brief),

                          const SizedBox(width: 16),

                          Expanded(child: workspace),
                        ],
                      )
                    : Column(
                        children: [
                          SizedBox(height: 170, child: brief),

                          const SizedBox(height: 12),

                          Expanded(child: workspace),
                        ],
                      ),
              );
            },
          ),
        ),
      ],
    );
  }
}
