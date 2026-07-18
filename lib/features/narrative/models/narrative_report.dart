import 'narrative_rating.dart';

/// A single student's rating for one category/grading period, from
/// enrollment-service's `NarrativeReportSerializer` (`grades/serializers.py`).
/// `unique_together = (enrollment, category, grading_period)` server-side —
/// only one report can exist per that triple, so writing a rating for an
/// already-rated student/category/period must PATCH the existing
/// [reportId], not POST a duplicate.
class NarrativeReport {
  const NarrativeReport({
    required this.reportId,
    required this.enrollmentId,
    required this.categoryId,
    required this.gradingPeriod,
    required this.rating,
  });

  factory NarrativeReport.fromJson(Map<String, dynamic> json) {
    return NarrativeReport(
      reportId: json['report_id'] as int,
      enrollmentId: json['enrollment'] as int,
      categoryId: json['category'] as int,
      gradingPeriod: json['grading_period'] as String? ?? '',
      rating: narrativeRatingFromJson(json['rating'] as String? ?? ''),
    );
  }

  final int reportId;
  final int enrollmentId;
  final int categoryId;
  final String gradingPeriod;
  final NarrativeRating rating;
}
