/// A single score row (e.g. "Quiz 1: 18/20") under a grading component,
/// from `GET/POST /api/score-entries/`.
class ScoreEntry {
  const ScoreEntry({
    required this.id,
    required this.enrollmentId,
    required this.componentId,
    required this.period,
    required this.label,
    required this.score,
    required this.maxScore,
  });

  factory ScoreEntry.fromJson(Map<String, dynamic> json) {
    return ScoreEntry(
      id: json['id'] as int,
      enrollmentId: json['enrollment'] as int,
      componentId: json['component'] as int,
      period: json['period'] as String? ?? '',
      label: json['label'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0,
      maxScore: (json['max_score'] as num?)?.toDouble() ?? 0,
    );
  }

  final int id;
  final int enrollmentId;
  final int componentId;
  final String period;
  final String label;
  final double score;
  final double maxScore;

  double get percent => maxScore <= 0 ? 0 : (score / maxScore) * 100;
}
