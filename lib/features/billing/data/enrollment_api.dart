import 'package:dio/dio.dart';

import '../../dashboard/models/recent_enrollment.dart';
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
