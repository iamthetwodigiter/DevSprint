import 'dart:convert';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/evaluation_model.dart';
import '../models/task_model.dart';
import '../services/gemini_service.dart';
part 'evaluation_notifier.g.dart';

@riverpod
class EvaluationNotifier extends _$EvaluationNotifier {
  @override
  FutureOr<EvaluationModel?> build() => null;

  Future<void> evaluateSubmission({
    required TaskModel task,
    required String userCode,
    required String submissionPackage,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final prompt =
          '''
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

      final attempt = await ref
          .read(geminiServiceProvider)
          .generateJson(prompt);
      return EvaluationModel.fromJson(
        Map<String, dynamic>.from(jsonDecode(attempt.response) as Map),
      );
    });
  }
  Future<void> clearEvaluation() async {
    state = const AsyncData(null);
  }

}
