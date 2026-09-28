class TaskSampleCase {
  final String input;
  final String output;
  final String explanation;

  const TaskSampleCase({
    required this.input,
    required this.output,
    required this.explanation,
  });

  factory TaskSampleCase.fromJson(Map<String, dynamic> json) => TaskSampleCase(
    input: json['input'] as String? ?? '',
    output: json['output'] as String? ?? '',
    explanation: json['explanation'] as String? ?? '',
  );
}

class TaskModel {
  final String taskId;
  final String title;
  final String language;
  final String difficulty;
  final int deadlineMinutes;
  final String summary;
  final String problemStatement;
  final List<String> constraints;
  final List<TaskSampleCase> sampleCases;
  final List<String> evaluationFocus;
  final String practiceType;
  final String? modelUsed;
  final List<String> supportingImages;

  const TaskModel({
    required this.taskId,
    required this.title,
    required this.language,
    required this.difficulty,
    required this.deadlineMinutes,
    required this.summary,
    required this.problemStatement,
    required this.constraints,
    required this.sampleCases,
    required this.evaluationFocus,
    this.practiceType = 'Engineering',
    this.modelUsed,
    this.supportingImages = const [],
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) => TaskModel(
    taskId: json['task_id'] as String? ?? '',
    title: json['title'] as String? ?? 'Untitled sprint',
    language: json['language'] as String? ?? 'Unknown',
    difficulty: json['difficulty'] as String? ?? 'Medium',
    deadlineMinutes: (json['deadline_minutes'] as num?)?.toInt() ?? 60,
    summary: json['summary'] as String? ?? '',
    problemStatement: json['problem_statement'] as String? ?? '',
    constraints: List<String>.from(json['constraints'] ?? const []),
    sampleCases: (json['sample_cases'] as List? ?? const [])
        .map(
          (e) => TaskSampleCase.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList(),
    evaluationFocus: List<String>.from(json['evaluation_focus'] ?? const []),
    practiceType: json['practice_type'] as String? ?? 'Engineering',
    modelUsed: json['model_used'] as String?,
    supportingImages: List<String>.from(json['supporting_images'] ?? const []),
  );

  Map<String, dynamic> toJson() => {
    'task_id': taskId,
    'title': title,
    'language': language,
    'difficulty': difficulty,
    'deadline_minutes': deadlineMinutes,
    'summary': summary,
    'problem_statement': problemStatement,
    'constraints': constraints,
    'sample_cases': sampleCases
        .map(
          (e) => {
            'input': e.input,
            'output': e.output,
            'explanation': e.explanation,
          },
        )
        .toList(),
    'evaluation_focus': evaluationFocus,
    'practice_type': practiceType,
    if (modelUsed != null) 'model_used': modelUsed,
    'supporting_images': supportingImages,
  };
}
