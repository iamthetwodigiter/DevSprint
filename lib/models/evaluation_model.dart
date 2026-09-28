class SubScores {
  final int correctness;
  final int cleanCode;
  final int modularity;
  final int reusability;

  const SubScores({
    required this.correctness,
    required this.cleanCode,
    required this.modularity,
    required this.reusability,
  });

  factory SubScores.fromJson(Map<String, dynamic> json) => SubScores(
    correctness: (json['correctness'] as num?)?.toInt() ?? 0,
    cleanCode: (json['clean_code'] as num?)?.toInt() ?? 0,
    modularity: (json['modularity'] as num?)?.toInt() ?? 0,
    reusability: (json['reusability'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'correctness': correctness,
    'clean_code': cleanCode,
    'modularity': modularity,
    'reusability': reusability,
  };
}

class EvaluationModel {
  final int overallScore;
  final SubScores subScores;
  final String verdict;
  final String summaryFeedback;
  final Map<String, String> detailedBreakdown;
  final List<String> keyStrengths;
  final List<String> areasForImprovement;
  final String suggestedRefactoring;

  const EvaluationModel({
    required this.overallScore,
    required this.subScores,
    required this.verdict,
    required this.summaryFeedback,
    required this.detailedBreakdown,
    required this.keyStrengths,
    required this.areasForImprovement,
    required this.suggestedRefactoring,
  });

  factory EvaluationModel.fromJson(Map<String, dynamic> json) {
    final raw = Map<String, dynamic>.from(json['detailed_breakdown'] ?? {});
    return EvaluationModel(
      overallScore: (json['overall_score'] as num?)?.toInt() ?? 0,
      subScores: SubScores.fromJson(
        Map<String, dynamic>.from(json['sub_scores'] ?? {}),
      ),
      verdict: json['verdict'] as String? ?? 'NEEDS_IMPROVEMENT',
      summaryFeedback: json['summary_feedback'] as String? ?? '',
      detailedBreakdown: raw.map((k, v) => MapEntry(k, '$v')),
      keyStrengths: List<String>.from(json['key_strengths'] ?? const []),
      areasForImprovement: List<String>.from(
        json['areas_for_improvement'] ?? const [],
      ),
      suggestedRefactoring: json['suggested_refactoring'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'overall_score': overallScore,
    'sub_scores': subScores.toJson(),
    'verdict': verdict,
    'summary_feedback': summaryFeedback,
    'detailed_breakdown': detailedBreakdown,
    'key_strengths': keyStrengths,
    'areas_for_improvement': areasForImprovement,
    'suggested_refactoring': suggestedRefactoring,
  };
}
