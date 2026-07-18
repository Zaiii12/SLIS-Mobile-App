import '../../dashboard/models/recent_enrollment.dart';
import '../models/pending_enrollment.dart';
import 'enrollment_api.dart';

/// Thin pass-through + the application-type derivation heuristic (see
/// PendingEnrollment's doc comment) — only resolved on the detail screen
/// per enrollment, never on the list, to avoid N+1 (a 19-row pending queue
/// would otherwise mean 19 extra enrollment-history + previous-school calls
/// just to render a list).
class EnrollmentRepository {
  EnrollmentRepository(this._api);

  final EnrollmentApi _api;

  Future<List<PendingEnrollment>> fetchPendingEnrollments() {
    return _api.fetchPendingEnrollments();
  }

  Future<List<RecentEnrollment>> fetchRecentEnrollments({int limit = 5}) {
    return _api.fetchRecentEnrollments(limit: limit);
  }

  /// Resolves applicationType + previous school for one enrollment.
  /// Order matters: a PreviousSchool record is checked first (Transferee is
  /// the more specific signal — a transferee could also technically have a
  /// prior local enrollment record if they left and came back, but the
  /// previous-school record is the stronger, more direct evidence of a
  /// transfer-in).
  Future<PendingEnrollment> resolveApplicationType(
    PendingEnrollment enrollment,
  ) async {
    final previousSchool = await _api.fetchPreviousSchool(enrollment.studentId);
    if (previousSchool != null) {
      return enrollment.copyWith(
        applicationType: 'Transferee',
        previousSchoolName: previousSchool.schoolName,
        previousSchoolAddress: previousSchool.schoolAddress,
      );
    }

    final hasPrior = await _api.hasPriorEnrollment(
      enrollment.studentId,
      enrollment.enrollmentId,
    );
    return enrollment.copyWith(
      applicationType: hasPrior ? 'Continuing' : 'New Student',
    );
  }
}
