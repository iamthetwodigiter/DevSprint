import 'dart:convert';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/task_model.dart';
import '../services/gemini_service.dart';
import '../services/hive_service.dart';

part 'task_notifier.g.dart';

@riverpod
class TaskNotifier extends _$TaskNotifier {
  String generationStep = 'Preparing challenge...';
  String? generationModel;
  int generationAttempt = 0;
  int generationTotalModels = GeminiService.models.length;
  @override
  FutureOr<TaskModel?> build() {
    final cached = ref.watch(hiveServiceProvider).getCurrentTask();
    return cached == null ? null : TaskModel.fromJson(cached);
  }

  Future<void> generateDailyTask({
    required String language,
    required String skillLevel,
    String focus = 'Practical software engineering',
    String practiceType = 'Engineering',
    String challengeStyle = 'Balanced',
    String developerNote = '',
  }) async {
    generationStep = 'Preparing challenge...';
    generationModel = null;
    generationAttempt = 0;
    generationTotalModels = GeminiService.models.length;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final prompt =
          '''
You are DevSprint Engine, an expert software engineering challenge designer.

Create a focused, practical challenge for:
Language / stack: $language
Skill level: $skillLevel
Practice type: $practiceType
Focus area: $focus
Challenge style: $challengeStyle
Developer note: $developerNote

Use the challenge style to shape the pacing and feel of the task:
- Balanced: practical scope with a clear finish line.
- Deep Dive: fewer requirements, but deeper engineering reasoning.
- Quick Win: compact scope that can be completed cleanly in a short session.
- Stretch: a demanding but still realistic task for the stated skill level.

DevSprint is NOT a competitive-programming app. Avoid generic DSA / LeetCode-style
puzzles unless explicitly requested. Prefer useful engineering practice such as
OOP, system design, APIs, backend services, databases, concurrency, networking,
debugging, testing, refactoring, security, DevOps, UI engineering, mobile,
cloud/distributed systems, or code-reading exercises.

The goal is a challenge a developer would willingly open the app to do. Avoid
artificial busywork. Deadline must be 30-180 minutes.
For UI/UX, frontend, mobile or visual tasks, include useful public reference image URLs only when they materially help the task. Otherwise return an empty array.

Return ONLY JSON matching:
{
  "task_id":"string",
  "title":"string",
  "language":"string",
  "difficulty":"Easy|Medium|Hard|Expert",
  "deadline_minutes":60,
  "summary":"string",
  "problem_statement":"markdown string",
  "constraints":["string"],
  "sample_cases":[{"input":"string","output":"string","explanation":"string"}],
  "evaluation_focus":["string"],
  "practice_type":"string",
  "supporting_images":["https://..." ]
}
''';

      generationStep = 'Generating a practical challenge...';
      state = const AsyncLoading();
      final attempt = await ref.read(geminiServiceProvider).generateJson(
        prompt,
        onAttempt: (model, index, total) {
          generationModel = model;
          generationAttempt = index;
          generationTotalModels = total;
          generationStep = 'Trying $model ($index/$total)...';
          state = const AsyncLoading();
        },
      );
      generationModel = attempt.model;
      generationStep = 'Validating the generated challenge...';
      state = const AsyncLoading();
      final json = Map<String, dynamic>.from(
        jsonDecode(attempt.response) as Map,
      );
      json['model_used'] = attempt.model;

      final task = TaskModel.fromJson(json);
      generationStep = 'Saving your new sprint...';
      state = const AsyncLoading();
      await ref.read(hiveServiceProvider).saveCurrentTask(json);
      return task;
    });
  }

  Future<void> cancelCurrentTask(String reason) async {
    await ref.read(hiveServiceProvider).clearCurrentTask();
    state = const AsyncData(null);
  }
}
