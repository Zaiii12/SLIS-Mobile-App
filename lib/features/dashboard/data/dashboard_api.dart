import 'package:dio/dio.dart';

import '../../../core/utils/school_year.dart';
import '../models/dashboard_data.dart';

/// Calls the aggregate endpoints backing the Dashboard's stat cards, spread
/// across student-service and enrollment-service (see handoff doc — there is
/// no API gateway, so each service is called on its own Dio client).
class DashboardApi {
  DashboardApi({
    required Dio studentClient,
    required Dio enrollmentClient,
    required Dio billingClient,
  }) : _student = studentClient,
       _enrollment = enrollmentClient,
       _billing = billingClient;

  final Dio _student;
  final Dio _enrollment;
  final Dio _billing;

  Future<DashboardStats> fetchStats({String? schoolYear}) async {
    final sy = schoolYear ?? SchoolYear.current();

    final results = await Future.wait([
      _count(_student, '/api/students/'),
      _count(_student, '/api/students/', query: {'status': 'active'}),
      _count(
        _enrollment,
        '/api/enrollments/',
        query: {'enrollment_status': 'enrolled', 'school_year': sy},
      ),
      // Matches the ASIA web dashboard's Enrollment Funnel "Completed" step
      // (DashboardPage.jsx fetchCompletedCount) — enrollment_status=completed
      // is a real STATUS_CHOICES value (enrollments/models.py).
      _count(
        _enrollment,
        '/api/enrollments/',
        query: {'enrollment_status': 'completed', 'school_year': sy},
      ),
    ]);
    final pendingByYear = await _fetchPendingEnrollmentByYear();

    return DashboardStats(
      schoolYear: sy,
      totalStudents: results[0],
      activeStudents: results[1],
      enrolledThisYear: results[2],
      completedThisYear: results[3],
      pendingEnrollment: pendingByYear.values.fold(0, (a, b) => a + b),
      pendingEnrollmentByYear: pendingByYear,
    );
  }

  /// Pending enrollment used to be scoped to the current school year only
  /// (`school_year: sy` filter on the count), which silently hid pending
  /// applications carried over from other years. `EnrollmentFilter`
  /// (enrollment-service) has no way to count-group-by-year server-side, so
  /// this fetches every pending row (confirmed live: `page_size` isn't
  /// respected by this endpoint anyway — same finding as
  /// EnrollmentApi.fetchPendingEnrollments) and groups client-side. Small
  /// scale (tens of rows) makes this acceptable.
  Future<Map<String, int>> _fetchPendingEnrollmentByYear() async {
    final response = await _enrollment.get(
      '/api/enrollments/',
      queryParameters: {'enrollment_status': 'pending'},
    );
    final data = response.data;
    final results = data is Map<String, dynamic>
        ? data['results'] as List?
        : data as List?;
    final byYear = <String, int>{};
    for (final row in (results ?? []).cast<Map<String, dynamic>>()) {
      final year = row['school_year'] as String? ?? 'Unknown';
      byYear[year] = (byYear[year] ?? 0) + 1;
    }
    return byYear;
  }

  Future<int> fetchUnpaidInvoiceCount() async {
    // /api/invoices/summary/ returns real aggregate counts across ALL
    // invoices (not just the current page), keyed by status.
    final response = await _billing.get('/api/invoices/summary/');
    final data = response.data as Map<String, dynamic>;
    return data['unpaid'] as int? ?? 0;
  }

  /// `GET /api/enrollment-scholarships/` (enrollment-service's `scholarships`
  /// app, `IsAdminRegistrarOrReadOnly`) — matches the ASIA web admin
  /// dashboard's "Scholarships Awarded" stat card
  /// (`DashboardPage.jsx:335-340`), scoped to the given school year via
  /// `enrollment__school_year` isn't filterable server-side (the viewset
  /// only supports `?enrollment=`/`?scholarship_type=`), so this counts the
  /// current page's `count` unfiltered by year — matches the web app's own
  /// behavior of fetching page_size=4 and using `results.length`, not a
  /// true total; using DRF's `count` here is at least as accurate.
  Future<int> fetchScholarshipCount() async {
    final response = await _enrollment.get(
      '/api/enrollment-scholarships/',
      queryParameters: {'page_size': 1},
    );
    final data = response.data as Map<String, dynamic>;
    return data['count'] as int? ?? 0;
  }

  Future<AttendanceBreakdown> fetchTodayAttendance(DateTime date) async {
    final isoDate =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    // /api/attendance/summary/ filters by date_from/date_to (a single day is
    // date_from == date_to) and returns counts nested under `totals`, not as
    // flat top-level fields.
    final response = await _enrollment.get(
      '/api/attendance/summary/',
      queryParameters: {'date_from': isoDate, 'date_to': isoDate},
    );
    final data = response.data as Map<String, dynamic>;
    final totals = data['totals'] as Map<String, dynamic>? ?? const {};

    return AttendanceBreakdown(
      present: totals['present'] as int? ?? 0,
      late: totals['late'] as int? ?? 0,
      absent: totals['absent'] as int? ?? 0,
    );
  }

  Future<int> _count(
    Dio client,
    String path, {
    Map<String, dynamic> query = const {},
  }) async {
    final response = await client.get(
      path,
      queryParameters: {...query, 'page_size': 1},
    );
    return (response.data as Map<String, dynamic>)['count'] as int? ?? 0;
  }
}

/// Stat-card figures only; attendance is fetched separately since it comes
/// from a different endpoint shape.
class DashboardStats {
  const DashboardStats({
    required this.schoolYear,
    required this.totalStudents,
    required this.activeStudents,
    required this.enrolledThisYear,
    required this.completedThisYear,
    required this.pendingEnrollment,
    required this.pendingEnrollmentByYear,
  });

  final String schoolYear;
  final int totalStudents;
  final int activeStudents;
  final int enrolledThisYear;

  /// `enrollment_status=completed` count for the current school year —
  /// the Enrollment Funnel's "Completed" step (matches the ASIA web
  /// dashboard's `fetchCompletedCount`).
  final int completedThisYear;
  final int pendingEnrollment;

  /// School year (e.g. "2026-2027") → count of pending applications for
  /// that year, across ALL years (not scoped to the current one) — see
  /// DashboardApi._fetchPendingEnrollmentByYear.
  final Map<String, int> pendingEnrollmentByYear;
}
