import 'package:dio/dio.dart';

import '../models/narrative_category.dart';
import '../models/narrative_rating.dart';
import '../models/narrative_report.dart';

List<Map<String, dynamic>> _resultsOf(dynamic data) {
  final results = data is Map<String, dynamic> ? data['results'] as List? : data as List?;
  return (results ?? []).cast<Map<String, dynamic>>();
}

/// Calls enrollment-service's narrative-report endpoints
/// (`grades/urls.py`: `narrative-categories`, `narrative-reports`).
/// `NarrativeReportViewSet` is `IsAdvisoryTeacherOrStaff` (teacher read+write
/// scoped to their own advisory students); `NarrativeCategoryViewSet` is
/// `IsAdminRegistrarOrReadOnly` (teacher can only read categories).
class NarrativeApi {
  NarrativeApi(this._enrollment);

  final Dio _enrollment;

  Future<List<NarrativeCategory>> fetchCategories() async {
    final response = await _enrollment.get(
      '/api/narrative-categories/',
      queryParameters: {'page_size': 500},
    );
    final categories = _resultsOf(response.data).map(NarrativeCategory.fromJson).toList();
    categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return categories;
  }

  /// Existing reports for one category/grading period, across every
  /// enrollment — used to pre-populate a roster before submission, same
  /// shape as `GradesApi.fetchGradedRoster`'s grades fetch.
  Future<List<NarrativeReport>> fetchReports({
    required int categoryId,
    required String gradingPeriod,
  }) async {
    final response = await _enrollment.get(
      '/api/narrative-reports/',
      queryParameters: {
        'category': categoryId,
        'grading_period': gradingPeriod,
        'page_size': 500,
      },
    );
    return _resultsOf(response.data).map(NarrativeReport.fromJson).toList();
  }

  Future<NarrativeReport> createReport({
    required int enrollmentId,
    required int categoryId,
    required String gradingPeriod,
    required NarrativeRating rating,
  }) async {
    final response = await _enrollment.post(
      '/api/narrative-reports/',
      data: {
        'enrollment': enrollmentId,
        'category': categoryId,
        'grading_period': gradingPeriod,
        'rating': rating.toJson(),
      },
    );
    return NarrativeReport.fromJson(response.data as Map<String, dynamic>);
  }

  Future<NarrativeReport> updateReport({
    required int reportId,
    required NarrativeRating rating,
  }) async {
    final response = await _enrollment.patch(
      '/api/narrative-reports/$reportId/',
      data: {'rating': rating.toJson()},
    );
    return NarrativeReport.fromJson(response.data as Map<String, dynamic>);
  }
}
