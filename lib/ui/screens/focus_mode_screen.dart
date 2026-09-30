import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_highlight/themes/night-owl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:highlight/highlight_core.dart';
import 'package:highlight/languages/all.dart';
import 'package:markdown_widget/markdown_widget.dart';

import '../../models/task_model.dart';
import '../../providers/evaluation_jobs_provider.dart';
import '../../providers/task_notifier.dart';
import '../../services/file_package_service.dart';
import '../../services/hive_service.dart';

class FocusModeScreen extends ConsumerStatefulWidget {
  final TaskModel task;

  const FocusModeScreen({super.key, required this.task});

  @override
  ConsumerState<FocusModeScreen> createState() => _FocusModeScreenState();
}

class _FocusModeScreenState extends ConsumerState<FocusModeScreen> {
  Timer? timer;
  late int remaining;
  late final CodeController codeController;

  final List<SelectedSourceFile> attachments = [];
  final ScrollController pageController = ScrollController();
  final FocusNode editorFocusNode = FocusNode();

  bool started = false;
  bool submitting = false;

  @override
  void initState() {
    super.initState();
    remaining = widget.task.deadlineMinutes * 60;
    codeController = CodeController(
      language: _languageFor(widget.task.language),
      params: const EditorParams(tabSpaces: 2),
    );
    codeController.popupController.enabled = true;
    editorFocusNode.addListener(() {
      if (editorFocusNode.hasFocus) _scrollEditorIntoView();
    });
  }

  Mode? _languageFor(String language) {
    final normalized = language.trim().toLowerCase();
    const aliases = <String, String>{
      'c++': 'cpp',
      'c plus plus': 'cpp',
      'c#': 'csharp',
      'c sharp': 'csharp',
      'js': 'javascript',
      'jsx': 'javascript',
      'ts': 'typescript',
      'tsx': 'typescript',
      'py': 'python',
      'golang': 'go',
      'kt': 'kotlin',
      'rs': 'rust',
      'sh': 'bash',
      'shell': 'bash',
      'postgres': 'pgsql',
      'postgresql': 'pgsql',
      'yml': 'yaml',
      'md': 'markdown',
      'text': 'plaintext',
      'plain text': 'plaintext',
    };
    return allLanguages[aliases[normalized] ?? normalized];
  }

  String get _submittedCode => codeController.fullText;

  int get _lineCount {
    if (_submittedCode.isEmpty) return 0;
    return '\n'.allMatches(_submittedCode).length + 1;
  }

  int get _characterCount => _submittedCode.length;

  @override
  void dispose() {
    timer?.cancel();
    pageController.dispose();
    editorFocusNode.dispose();
    codeController.dispose();
    super.dispose();
  }

  void start() {
    setState(() => started = true);
    final now = DateTime.now();
    ref.read(hiveServiceProvider).saveSession(
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
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> addFiles() async {
    final files = await ref.read(filePackageServiceProvider).pickFiles();
    if (files.isNotEmpty && mounted) {
      setState(() => attachments.addAll(files));
    }
  }

  Future<void> addZip() async {
    final zip = await ref.read(filePackageServiceProvider).pickZip();
    if (zip != null && mounted) {
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
        sourceText = await service.buildEvaluationSource(attachments);
        packagePath = zip.path;
        packageInfo = 'ZIP submission package created.\n\n$sourceText';
      } else {
        final inlineCode = _submittedCode;
        final limitedCode = inlineCode.length > 160000
            ? inlineCode.substring(0, 160000)
            : inlineCode;
        packageInfo = 'Inline submission only.\nCode:\n$limitedCode';
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
          'code': _submittedCode,
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
        userCode: _submittedCode,
        submissionPackage: packageInfo,
        sprintRecord: sprintRecord,
      );

      await ref.read(hiveServiceProvider).clearSession();
      await ref.read(taskProvider.notifier).cancelCurrentTask('Submitted');
      if (mounted) Navigator.pop(context);
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
        'code': _submittedCode,
        'files': attachments.map((file) => file.name).toList(),
        'package': 'Sprint abandoned before submission.',
        'package_path': packagePath,
        'updated_at': now.toUtc().toIso8601String(),
        'revision': now.microsecondsSinceEpoch.toString(),
      },
    });

    await ref.read(hiveServiceProvider).clearSession();
    await ref.read(taskProvider.notifier).cancelCurrentTask('Failed (Gave Up)');
    if (mounted) Navigator.pop(context);
  }

  void _scrollEditorIntoView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !pageController.hasClients) return;
      final target = pageController.position.maxScrollExtent;
      pageController.animateTo(
        target.clamp(0, pageController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
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
        resizeToAvoidBottomInset: true,
        appBar: _appBar(context),
        body: started ? _activeSprint(context) : _brief(context),
      ),
    );
  }

  PreferredSizeWidget _appBar(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AppBar(
      leading: const BackButton(),
      titleSpacing: 0,
      title: Text(
        started ? 'Focus mode' : 'Challenge brief',
        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      actions: [
        if (started) ...[
          _TimerBadge(time: time, urgent: remaining <= 300),
          const SizedBox(width: 12),
        ],
        if (!started && widget.task.modelUsed != null)
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Icon(Icons.auto_awesome_rounded, color: cs.primary),
          ),
      ],
    );
  }

  Widget _brief(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        _TaskHeader(task: widget.task),
        const SizedBox(height: 14),
        _Surface(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: _buildMarkdown(context),
          ),
        ),
        if (widget.task.constraints.isNotEmpty) ...[
          const SizedBox(height: 12),
          _InfoSection(
            icon: Icons.rule_rounded,
            title: 'Constraints',
            child: Column(
              children: [
                for (final constraint in widget.task.constraints)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_rounded, size: 17, color: cs.primary),
                        const SizedBox(width: 8),
                        Expanded(child: Text(constraint)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (widget.task.sampleCases.isNotEmpty) ...[
          const SizedBox(height: 12),
          _InfoSection(
            icon: Icons.lightbulb_outline_rounded,
            title: 'Examples',
            child: Column(
              children: [
                for (var i = 0; i < widget.task.sampleCases.length; i++)
                  ExpansionTile(
                    dense: true,
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
                    shape: const Border(),
                    collapsedShape: const Border(),
                    title: Text(widget.task.sampleCases[i].input),
                    subtitle: Text(
                      'Expected: ${widget.task.sampleCases[i].output}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(widget.task.sampleCases[i].explanation),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: start,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Start sprint'),
        ),
        const SizedBox(height: 8),
        Text(
          'The timer starts when you begin. Files can be attached during the sprint.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _activeSprint(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardOpen = media.viewInsets.bottom > 0;
    final wide = media.size.width >= 900;
    final editorHeight = wide ? 560.0 : 430.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          controller: pageController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
          padding: EdgeInsets.fromLTRB(
            wide ? 20 : 14,
            14,
            wide ? 20 : 14,
            24 + media.viewInsets.bottom,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ActiveHeader(task: widget.task, compact: keyboardOpen),
                  const SizedBox(height: 12),
                  if (!wide) ...[
                    _problemAccordion(context),
                    const SizedBox(height: 12),
                  ],
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 310, child: _desktopProblem(context)),
                        const SizedBox(width: 14),
                        Expanded(child: _workspace(context, editorHeight)),
                      ],
                    )
                  else
                    _workspace(context, editorHeight),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _desktopProblem(BuildContext context) {
    final theme = Theme.of(context);
    return _Surface(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(icon: Icons.description_outlined, title: 'Problem'),
            const SizedBox(height: 12),
            _buildMarkdown(context),
            if (widget.task.constraints.isNotEmpty) ...[
              const SizedBox(height: 18),
              const _SectionTitle(icon: Icons.rule_rounded, title: 'Constraints'),
              const SizedBox(height: 8),
              for (final constraint in widget.task.constraints)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Text('• $constraint', style: theme.textTheme.bodySmall),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _problemAccordion(BuildContext context) {
    final theme = Theme.of(context);
    return _Surface(
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          'Problem',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        leading: const Icon(Icons.description_outlined),
        children: [_buildMarkdown(context)],
      ),
    );
  }

  Widget _workspace(BuildContext context, double editorHeight) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(Icons.code_rounded, color: cs.onPrimaryContainer),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Solution',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${widget.task.language}  •  ${widget.task.practiceType}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _ToolbarButton(
                  icon: Icons.attach_file_rounded,
                  label: 'Files',
                  onPressed: submitting ? null : addFiles,
                ),
                const SizedBox(width: 7),
                _ToolbarButton(
                  icon: Icons.folder_zip_outlined,
                  label: 'ZIP',
                  onPressed: submitting ? null : addZip,
                ),
              ],
            ),
          ),
          if (attachments.isNotEmpty) _attachmentBar(context),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            height: editorHeight,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: .7)),
            ),
            child: CodeTheme(
              data: CodeThemeData(styles: dark ? nightOwlTheme : githubTheme),
              child: CodeField(
                controller: codeController,
                focusNode: editorFocusNode,
                expands: true,
                wrap: true,
                readOnly: submitting,
                padding: const EdgeInsets.fromLTRB(6, 12, 12, 12),
                textStyle: GoogleFonts.jetBrainsMono(
                  fontSize: 13,
                  height: 1.55,
                ),
                background: Colors.transparent,
                cursorColor: cs.primary,
                gutterStyle: GutterStyle(
                  width: 48,
                  showLineNumbers: true,
                  showFoldingHandles: true,
                  showErrors: false,
                  margin: 8,
                  textStyle: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: dark ? const Color(0xFF6E7681) : const Color(0xFF57606A),
                  ),
                ),
                onChanged: (_) {
                  if (mounted) setState(() {});
                },
              ),
            ),
          ),
          _editorFooter(context),
        ],
      ),
    );
  }

  Widget _attachmentBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        border: Border.symmetric(
          horizontal: BorderSide(color: cs.outlineVariant.withValues(alpha: .5)),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: attachments.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, index) {
          final file = attachments[index];
          return InputChip(
            visualDensity: VisualDensity.compact,
            avatar: const Icon(Icons.description_outlined, size: 15),
            label: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 190),
              child: Text(file.name, overflow: TextOverflow.ellipsis),
            ),
            onDeleted: submitting
                ? null
                : () => setState(() => attachments.removeAt(index)),
          );
        },
      ),
    );
  }

  Widget _editorFooter(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _Shortcut(text: 'Tab', detail: 'indent'),
                SizedBox(width: 6),
                _Shortcut(text: 'Shift + Tab', detail: 'outdent'),
                SizedBox(width: 6),
                _Shortcut(text: 'Ctrl + /', detail: 'comment'),
                SizedBox(width: 6),
                _Shortcut(text: 'Ctrl + Space', detail: 'autocomplete'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.data_object_rounded, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                '$_lineCount lines',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$_characterCount chars',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (submitting)
                Text(
                  'Preparing submission…',
                  style: theme.textTheme.labelMedium?.copyWith(color: cs.primary),
                ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton(
                      onPressed: submitting ? null : giveUp,
                      child: const Text('Give up'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: submitting ? null : submit,
                      icon: submitting
                          ? const SizedBox.square(
                              dimension: 17,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(submitting ? 'Submitting…' : 'Submit solution'),
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  OutlinedButton(
                    onPressed: submitting ? null : giveUp,
                    child: const Text('Give up'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: submitting ? null : submit,
                      icon: submitting
                          ? const SizedBox.square(
                              dimension: 17,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(submitting ? 'Submitting…' : 'Submit solution'),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMarkdown(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final bodyStyle = (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
      color: theme.colorScheme.onSurface,
      height: 1.55,
    );
    final baseConfig = dark
        ? MarkdownConfig.darkConfig
        : MarkdownConfig.defaultConfig;
    final preConfig = dark
        ? PreConfig.darkConfig.copy(
            theme: nightOwlTheme,
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
          )
        : const PreConfig().copy(theme: githubTheme);

    final config = baseConfig.copy(
      configs: [
        PConfig(textStyle: bodyStyle),
        H1Config(style: theme.textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.w800)),
        H2Config(style: theme.textTheme.headlineSmall!.copyWith(fontWeight: FontWeight.w800)),
        H3Config(style: theme.textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w800)),
        H4Config(style: theme.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w700)),
        H5Config(style: theme.textTheme.titleSmall!.copyWith(fontWeight: FontWeight.w700)),
        H6Config(style: theme.textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w700)),
        dark ? CodeConfig.darkConfig : const CodeConfig(),
        preConfig,
        LinkConfig(
          style: TextStyle(
            color: theme.colorScheme.primary,
            decoration: TextDecoration.underline,
          ),
        ),
        HrConfig(color: theme.dividerColor),
        TableConfig(headerStyle: bodyStyle.copyWith(fontWeight: FontWeight.w700)),
      ],
    );

    try {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: MarkdownGenerator().buildWidgets(
          widget.task.problemStatement,
          config: config,
        ),
      );
    } catch (_) {
      return SelectableText(widget.task.problemStatement, style: bodyStyle);
    }
  }
}

class _TaskHeader extends StatelessWidget {
  final TaskModel task;
  const _TaskHeader({required this.task});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return _Surface(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _MetaPill(icon: Icons.code_rounded, label: task.language),
                _MetaPill(icon: Icons.speed_rounded, label: task.difficulty),
                _MetaPill(icon: Icons.category_outlined, label: task.practiceType),
                _MetaPill(icon: Icons.schedule_rounded, label: '${task.deadlineMinutes} min'),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              task.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.12,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              task.summary,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveHeader extends StatelessWidget {
  final TaskModel task;
  final bool compact;
  const _ActiveHeader({required this.task, required this.compact});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return _Surface(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, compact ? 11 : 14, 16, compact ? 11 : 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(Icons.terminal_rounded, color: cs.onPrimaryContainer),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${task.language}  •  ${task.practiceType}',
                    style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (!compact) ...[
              const SizedBox(width: 12),
              const _StatusDot(label: 'Sprint active'),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimerBadge extends StatelessWidget {
  final String time;
  final bool urgent;
  const _TimerBadge({required this.time, required this.urgent});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = urgent ? cs.error : cs.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 17, color: color),
          const SizedBox(width: 7),
          Text(
            time,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  const _ToolbarButton({required this.icon, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 11),
        visualDensity: VisualDensity.compact,
      ),
      icon: Icon(icon, size: 17),
      label: Text(label),
    );
  }
}

class _Shortcut extends StatelessWidget {
  final String text;
  final String detail;
  const _Shortcut({required this.text, required this.detail});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.labelSmall,
          children: [
            TextSpan(
              text: text,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            TextSpan(text: '  $detail'),
          ],
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final String label;
  const _StatusDot({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: cs.primary),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _InfoSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _InfoSection({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(icon: icon, title: title),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  final Widget child;
  const _Surface({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border.all(color: cs.outlineVariant.withValues(alpha: .55)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(16), child: child),
    );
  }
}
