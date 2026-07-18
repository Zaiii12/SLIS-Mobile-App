import '../models/narrative_category.dart';
import '../models/narrative_rating.dart';
import '../models/narrative_report.dart';
import 'narrative_api.dart';

/// Thin pass-through over [NarrativeApi], matching the Grades/Attendance
/// repository pattern.
class NarrativeRepository {
  NarrativeRepository(this._api);

  final NarrativeApi _api;

  Future<List<NarrativeCategory>> fetchCategories() => _api.fetchCategories();

  Future<List<NarrativeReport>> fetchReports({
    required int categoryId,
    required String gradingPeriod,
  }) =>
      _api.fetchReports(categoryId: categoryId, gradingPeriod: gradingPeriod);

  Future<NarrativeReport> createReport({
    required int enrollmentId,
    required int categoryId,
    required String gradingPeriod,
    required NarrativeRating rating,
  }) =>
      _api.createReport(
        enrollmentId: enrollmentId,
        categoryId: categoryId,
        gradingPeriod: gradingPeriod,
        rating: rating,
      );

  Future<NarrativeReport> updateReport({
    required int reportId,
    required NarrativeRating rating,
  }) =>
      _api.updateReport(reportId: reportId, rating: rating);
}
