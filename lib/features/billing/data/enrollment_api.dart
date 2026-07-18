import 'package:dio/dio.dart';

import '../../advisory/models/section_advisory.dart' show schoolLevelFromJson;
import '../../dashboard/models/recent_enrollment.dart';
import '../../grades/models/grade_overview_row.dart';
import '../models/enrollment.dart';
import '../models/pending_enrollment.dart';

/// Calls enrollment-service's `GET /api/enrollments/` and student-service's
/// `GET /api/previous_schools/` to build the "Pending Enrollment" reminders
/// list from real data (see PendingEnrollment doc comment for what's real
/// vs. derived).
class EnrollmentApi {
  EnrollmentApi({required Dio enrollmentClient, required Dio studentClient})
    : _enrollment = enrollmentClient,
      _student = studentClient;

  final Dio _enrollment;
  final Dio _student;

  /// `EnrollmentViewSet` has no SearchFilter (confirmed in enrollments/
  /// views.py — only DjangoFilterBackend) and its `page_size` query param
  /// isn't respected in practice (verified live: passing page_size=5 still
  /// returned all 19 pending rows), so this fetches everything in one call
  /// and filtering/search happens client-side — acceptable at pending-queue
  /// scale (tens, not thousands, of rows).
  Future<List<PendingEnrollment>> fetchPendingEnrollments() async {
    final response = await _enrollment.get(
      '/api/enrollments/',
      queryParameters: {'enrollment_status': 'pending'},
    );
    final data = response.data;
    final results = data is Map<String, dynamic>
        ? data['results'] as List?
        : data as List?;
    return (results ?? [])
        .cast<Map<String, dynamic>>()
        .map(PendingEnrollment.fromJson)
        .toList();
  }

  /// Real signal #1 for the application-type heuristic: any enrollment
  /// record for this student other than the pending one itself means
  /// they've been enrolled before (Continuing), not a first-time applicant.
  Future<bool> hasPriorEnrollment(
    String studentId,
    String excludingEnrollmentId,
  ) async {
    final response = await _enrollment.get(
      '/api/enrollments/',
      queryParameters: {'student_id': studentId},
    );
    final data = response.data;
    final results = data is Map<String, dynamic>
        ? data['results'] as List?
        : data as List?;
    if (results == null) return false;
    return results.cast<Map<String, dynamic>>().any(
      (r) => r['enrollment_id'].toString() != excludingEnrollmentId,
    );
  }

  /// Newest-first slice of every enrollment (any status), for the admin
  /// dashboard's "Recent Enrollments" card — distinct from
  /// [fetchPendingEnrollments], which filters to `enrollment_status=pending`
  /// only. `ordering=-enrollment_id` is real (`EnrollmentViewSet.
  /// ordering_fields` includes `enrollment_id`, `enrollments/views.py:689`);
  /// there's no `created_at` on the model, so the auto-incrementing PK is
  /// the only genuine newest-first signal. `limit` is applied client-side
  /// via slicing since page_size isn't respected server-side for this
  /// endpoint (confirmed live — see fetchPendingEnrollments' doc comment).
  Future<List<RecentEnrollment>> fetchRecentEnrollments({int limit = 5}) async {
    final response = await _enrollment.get(
      '/api/enrollments/',
      queryParameters: {'ordering': '-enrollment_id'},
    );
    final data = response.data;
    final results = data is Map<String, dynamic>
        ? data['results'] as List?
        : data as List?;
    return (results ?? [])
        .cast<Map<String, dynamic>>()
        .take(limit)
        .map(RecentEnrollment.fromJson)
        .toList();
  }

  /// Registrar-facing Grade Overview roster: enrolled students matching the
  /// given filters, each with computed average/passed/failed/total across
  /// every subject and grading period recorded so far. Mirrors ASIA web's
  /// `GradesPage.jsx` `OverviewTab.fetchPage` exactly — there is no backend
  /// endpoint that returns this pre-aggregated, so it's one `/api/enrollments/`
  /// call plus one `/api/grades/?enrollment=<id>` call per row, joined and
  /// averaged client-side. `remarks` (passed/failed) mirrors the 75-point
  /// passing threshold ASIA's web uses (`GradesPage.jsx`, `r.avg >= 75`).
  Future<List<GradeOverviewRow>> fetchGradeOverviewRoster({
    String? schoolYear,
    String? schoolLevel,
    String? gradeLevel,
    String? search,
  }) async {
    final response = await _enrollment.get(
      '/api/enrollments/',
      queryParameters: {
        'enrollment_status': 'enrolled',
        if (schoolYear != null && schoolYear.isNotEmpty)
          'school_year': schoolYear,
        if (schoolLevel != null && schoolLevel.isNotEmpty)
          'school_level': schoolLevel,
        if (gradeLevel != null && gradeLevel.isNotEmpty)
          'grade_level': gradeLevel,
        if (search != null && search.isNotEmpty) 'search': search,
        'page_size': 500,
      },
    );
    final data = response.data;
    final results =
        (data is Map<String, dynamic>
            ? data['results'] as List?
            : data as List?) ??
        [];
    final enrollments = results.cast<Map<String, dynamic>>();

    final gradeLists = await Future.wait(
      enrollments.map((e) async {
        final gradesResponse = await _enrollment.get(
          '/api/grades/',
          queryParameters: {'enrollment': e['enrollment_id'], 'page_size': 500},
        );
        final gradesData = gradesResponse.data;
        final gradesResults =
            (gradesData is Map<String, dynamic>
                ? gradesData['results'] as List?
                : gradesData as List?) ??
            [];
        return gradesResults.cast<Map<String, dynamic>>();
      }),
    );

    return [
      for (var i = 0; i < enrollments.length; i++)
        _buildOverviewRow(enrollments[i], gradeLists[i]),
    ];
  }

  GradeOverviewRow _buildOverviewRow(
    Map<String, dynamic> enrollment,
    List<Map<String, dynamic>> grades,
  ) {
    final studentDetail = enrollment['student_detail'] as Map<String, dynamic>?;
    final numericGrades = grades
        .map((g) => _parseNumericGrade(g['numeric_grade']))
        .whereType<double>()
        .toList();
    final average = numericGrades.isEmpty
        ? null
        : numericGrades.reduce((a, b) => a + b) / numericGrades.length;
    final passed = numericGrades.where((g) => g >= 75).length;
    final failed = numericGrades.where((g) => g < 75).length;

    return GradeOverviewRow(
      enrollmentId: enrollment['enrollment_id'] as int,
      studentName: enrollment['student_name'] as String? ?? '',
      lrn: studentDetail?['lrn'] as String? ?? '',
      studentNumber: studentDetail?['student_number'] as String? ?? '',
      schoolLevel: schoolLevelFromJson(
        enrollment['school_level'] as String? ?? '',
      ),
      gradeLevel: enrollment['grade_level'] as String? ?? '',
      section: enrollment['section'] as String? ?? '',
      schoolYear: enrollment['school_year'] as String? ?? '',
      strand: enrollment['strand'] as String?,
      average: average,
      passed: passed,
      failed: failed,
      total: numericGrades.length,
    );
  }

  /// Registrar-facing Enrollments tab roster: enrollments matching the given
  /// filters (any status, unlike [fetchGradeOverviewRoster] which is fixed
  /// to `enrolled`). `page_size` isn't respected server-side (see
  /// [fetchPendingEnrollments]'s doc comment) so this fetches everything
  /// matching the filters in one call.
  Future<List<Enrollment>> fetchEnrollments({
    String? schoolYear,
    String? schoolLevel,
    String? gradeLevel,
    String? enrollmentStatus,
    String? search,
  }) async {
    final response = await _enrollment.get(
      '/api/enrollments/',
      queryParameters: {
        if (schoolYear != null && schoolYear.isNotEmpty)
          'school_year': schoolYear,
        if (schoolLevel != null && schoolLevel.isNotEmpty)
          'school_level': schoolLevel,
        if (gradeLevel != null && gradeLevel.isNotEmpty)
          'grade_level': gradeLevel,
        if (enrollmentStatus != null && enrollmentStatus.isNotEmpty)
          'enrollment_status': enrollmentStatus,
        if (search != null && search.isNotEmpty) 'search': search,
        'page_size': 500,
      },
    );
    final data = response.data;
    final results =
        (data is Map<String, dynamic>
            ? data['results'] as List?
            : data as List?) ??
        [];
    return results
        .cast<Map<String, dynamic>>()
        .map(Enrollment.fromJson)
        .toList();
  }

  Future<Enrollment> fetchEnrollment(String enrollmentId) async {
    final response = await _enrollment.get('/api/enrollments/$enrollmentId/');
    return Enrollment.fromJson(response.data as Map<String, dynamic>);
  }

  /// `PATCH /api/enrollments/<id>/` — only [section] and [enrollmentStatus]
  /// are exposed for mobile quick-edit (see [Enrollment]'s doc comment for
  /// why grade/level/strand/semester are excluded). Registrar has write
  /// access per `WRITE_ROLES_DEFAULT` in enrollment-service's
  /// `accounts/permissions.py`.
  Future<Enrollment> updateEnrollment(
    String enrollmentId, {
    String? section,
    String? enrollmentStatus,
  }) async {
    final response = await _enrollment.patch(
      '/api/enrollments/$enrollmentId/',
      data: {
        if (section != null) 'section': section,
        if (enrollmentStatus != null) 'enrollment_status': enrollmentStatus,
      },
    );
    return Enrollment.fromJson(response.data as Map<String, dynamic>);
  }

  /// Real signal #2: a PreviousSchool row (student-service) means Transferee.
  /// Returns null if none exists.
  Future<({String schoolName, String schoolAddress})?> fetchPreviousSchool(
    String studentId,
  ) async {
    final response = await _student.get(
      '/api/previous_schools/',
      queryParameters: {'student_id': studentId},
    );
    final data = response.data;
    final results = data is Map<String, dynamic>
        ? data['results'] as List?
        : data as List?;
    if (results == null || results.isEmpty) return null;
    final first = results.first as Map<String, dynamic>;
    return (
      schoolName: first['school_name'] as String? ?? '',
      schoolAddress: first['school_address'] as String? ?? '',
    );
  }
}

/// DRF's `DecimalField` serializes `numeric_grade` as a string (e.g.
/// `"85.00"`) by default, not a JSON number — must parse both.
double? _parseNumericGrade(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value as String);
}
