import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/evaluation_model.dart';
import '../models/task_model.dart';
import '../services/gemini_service.dart';
import '../services/hive_service.dart';

class EvaluationJobController extends Notifier<List<Map<String, dynamic>>> {
  HiveService get _hive => ref.read(hiveServiceProvider);
  GeminiService get _gemini => ref.read(geminiServiceProvider);

  @override
  List<Map<String, dynamic>> build() {
    final jobs = _hive.getEvaluationJobs();
    final normalized = <Map<String, dynamic>>[];

    for (final job in jobs) {
      final copy = _deepCopy(job);
      if (copy['status'] == 'running') {
        copy['status'] = 'interrupted';
        copy['step'] = 'Evaluation was interrupted because DevSprint was closed.';
        copy['error'] =
            'The app was closed before the background evaluation finished.';
        _hive.saveEvaluationJob(copy);
      }
      normalized.add(copy);
    }

    normalized.sort(_compareJobs);
    return normalized;
  }

  Future<void> startEvaluation({
    required String jobId,
    required TaskModel task,
    required String userCode,
    required String submissionPackage,
    required Map<String, dynamic> sprintRecord,
  }) async {
    final existing = _find(jobId);
    if (existing != null && existing['status'] == 'running') return;

    final now = DateTime.now().toUtc().toIso8601String();
    final job = <String, dynamic>{
      'id': jobId,
      'created_at': now,
      'started_at': now,
      'updated_at': now,
      'status': 'running',
      'step': 'Preparing submission for Gemini...',
      'model': null,
      'attempt': 0,
      'total_models': GeminiService.models.length,
      'error': null,
      'task': task.toJson(),
      'user_code': userCode,
      'submission_package': submissionPackage,
      'sprint_record': _deepCopy(sprintRecord),
      'evaluation': null,
    };

    await _hive.saveEvaluationJob(job);
    _replace(job);
    unawaited(_run(jobId));
  }

  Map<String, dynamic>? recordForJob(String jobId) {
    final job = _find(jobId);
    if (job == null || job['sprint_record'] is! Map) return null;
    final record = _deepCopy(
      Map<String, dynamic>.from(job['sprint_record'] as Map),
    );
    if (job['evaluation'] is Map) {
      final evaluation = Map<String, dynamic>.from(job['evaluation'] as Map);
      record['evaluation'] = evaluation;
      record['score'] = (evaluation['overall_score'] as num?)?.toInt() ?? 0;
      record['success'] = evaluation['verdict'] == 'PASSED';
    }
    record['evaluation_status'] = 'completed';
    return record;
  }

  Future<void> retry(String jobId) async {
    final current = _find(jobId);
    if (current == null) return;

    final job = _deepCopy(current);
    job['status'] = 'running';
    job['step'] = 'Retrying evaluation...';
    job['error'] = null;
    job['model'] = null;
    job['attempt'] = 0;
    job['started_at'] = DateTime.now().toUtc().toIso8601String();
    job['updated_at'] = job['started_at'];
    await _hive.saveEvaluationJob(job);
    _replace(job);
    unawaited(_run(jobId));
  }

  Future<void> _run(String jobId) async {
    final job = _find(jobId);
    if (job == null) return;

    try {
      _update(jobId, {
        'step': 'Sending the submission to Gemini...',
      });

      final task = TaskModel.fromJson(
        Map<String, dynamic>.from(job['task'] as Map),
      );
      final userCode = job['user_code'] as String? ?? '';
      final submissionPackage = job['submission_package'] as String? ?? '';

      final prompt = '''
You are DevSprint Evaluator, a strict senior software architect.

TASK
Title: ${task.title}
Language: ${task.language}
Practice type: ${task.practiceType}
Problem:
${task.problemStatement}
Constraints:
${task.constraints.join('\n')}

SUBMISSION
$submissionPackage

Inline editor code:
$userCode

Evaluate the submission against the task.
Return ONLY JSON:
{
 "overall_score":0,
 "sub_scores":{"correctness":0,"clean_code":0,"modularity":0,"reusability":0},
 "verdict":"PASSED|NEEDS_IMPROVEMENT|FAILED",
 "summary_feedback":"string",
 "detailed_breakdown":{"correctness_notes":"string","clean_code_notes":"string","modularity_notes":"string","reusability_notes":"string"},
 "key_strengths":["string"],
 "areas_for_improvement":["string"],
 "suggested_refactoring":"string"
}
Each sub-score is out of 25 and overall_score must be their exact sum.
''';

      final attempt = await _gemini.generateJson(
        prompt,
        onAttempt: (model, index, total) {
          _update(jobId, {
            'model': model,
            'attempt': index,
            'total_models': total,
            'step': 'Evaluating with $model... ',
          });
        },
      );

      _update(jobId, {
        'model': attempt.model,
        'step': 'Validating Gemini response...',
      });

      final evaluation = EvaluationModel.fromJson(
        Map<String, dynamic>.from(jsonDecode(attempt.response) as Map),
      );

      _update(jobId, {
        'step': 'Saving evaluation result...',
        'evaluation': evaluation.toJson(),
      });

      final current = _find(jobId);
      if (current == null) return;
      final record = _deepCopy(
        Map<String, dynamic>.from(current['sprint_record'] as Map),
      );
      final now = DateTime.now().toUtc();
      record['success'] = evaluation.verdict == 'PASSED';
      record['score'] = evaluation.overallScore;
      record['evaluation'] = evaluation.toJson();
      record['evaluation_status'] = 'completed';
      record['evaluatedAt'] = now.toIso8601String();
      final submission = record['submission'] is Map
          ? Map<String, dynamic>.from(record['submission'] as Map)
          : <String, dynamic>{};
      submission['evaluation_model'] = attempt.model;
      submission['updated_at'] = now.toIso8601String();
      record['submission'] = submission;

      await _hive.saveSprintRecord(record);

      _update(jobId, {
        'status': 'completed',
        'step': 'Evaluation complete.',
        'model': attempt.model,
        'evaluation': evaluation.toJson(),
        'finished_at': now.toIso8601String(),
        'error': null,
      });
    } catch (error) {
      final message = _friendlyError(error);
      _update(jobId, {
        'status': 'failed',
        'step': 'Evaluation failed.',
        'error': message,
        'finished_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('api key is not configured')) {
      return 'Gemini API key is not configured. Add it in Settings and retry.';
    }
    if (message.contains('clientexception') ||
        message.contains('socketexception') ||
        message.contains('failed host lookup') ||
        message.contains('network')) {
      return 'DevSprint could not reach Gemini. Check your internet connection and retry.';
    }
    if (message.contains('quota') || message.contains('rate limit')) {
      return 'Gemini rate limits or quota prevented the evaluation. Retry later.';
    }
    if (message.contains('context') ||
        message.contains('token') ||
        message.contains('too large') ||
        message.contains('payload')) {
      return 'The submission is too large for the evaluation request. Reduce the attached source and retry.';
    }
    return 'DevSprint could not evaluate the submission. Retry from Background evaluations.';
  }

  Map<String, dynamic>? _find(String id) {
    for (final job in state) {
      if (job['id'] == id) return job;
    }
    return null;
  }

  void _update(String id, Map<String, dynamic> changes) {
    final current = _find(id);
    if (current == null) return;
    final job = _deepCopy(current)..addAll(changes);
    job['updated_at'] = DateTime.now().toUtc().toIso8601String();
    _hive.saveEvaluationJob(job);
    _replace(job);
  }

  void _replace(Map<String, dynamic> job) {
    final next = state.where((item) => item['id'] != job['id']).toList();
    next.add(_deepCopy(job));
    next.sort(_compareJobs);
    state = next;
  }

  int _compareJobs(Map<String, dynamic> a, Map<String, dynamic> b) {
    final ad = DateTime.tryParse(a['updated_at'] as String? ?? '') ?? DateTime(1970);
    final bd = DateTime.tryParse(b['updated_at'] as String? ?? '') ?? DateTime(1970);
    return bd.compareTo(ad);
  }

  Map<String, dynamic> _deepCopy(Map<String, dynamic> value) {
    return Map<String, dynamic>.from(_copyValue(value) as Map);
  }

  dynamic _copyValue(dynamic value) {
    if (value is Map) {
      return value.map((key, value) => MapEntry(key, _copyValue(value)));
    }
    if (value is List) return value.map(_copyValue).toList();
    return value;
  }
}

final evaluationJobsProvider =
    NotifierProvider<EvaluationJobController, List<Map<String, dynamic>>>(
  EvaluationJobController.new,
);
