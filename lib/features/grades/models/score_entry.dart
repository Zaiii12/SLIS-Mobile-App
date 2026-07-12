/// A single score row (e.g. "Quiz 1: 18/20") under a grading component,
/// from `GET/POST /api/score-entries/`. Field names confirmed against
/// `grading/serializers.py`'s `ScoreEntrySerializer`: pk is
/// `score_entry_id`, component FK is `grading_component` (not `component`),
/// period is `grading_period` (not `period`) — and a `subject` FK is
/// required on create/update alongside `enrollment`, since a `ScoreEntry`
/// isn't implicitly scoped to a subject via its component.
class ScoreEntry {
  const ScoreEntry({
    required this.id,
    required this.enrollmentId,
    required this.subjectId,
    required this.componentId,
    required this.period,
    required this.label,
    required this.score,
    required this.maxScore,
  });

  factory ScoreEntry.fromJson(Map<String, dynamic> json) {
    return ScoreEntry(
      id: json['score_entry_id'] as int,
      enrollmentId: json['enrollment'] as int,
      subjectId: json['subject'] as int,
      componentId: json['grading_component'] as int,
      period: json['grading_period'] as String? ?? '',
      label: json['label'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0,
      maxScore: (json['max_score'] as num?)?.toDouble() ?? 0,
    );
  }

  final int id;
  final int enrollmentId;
  final int subjectId;
  final int componentId;
  final String period;
  final String label;
  final double score;
  final double maxScore;

  double get percent => maxScore <= 0 ? 0 : (score / maxScore) * 100;
}
