import 'package:dio/dio.dart';

import '../../../core/utils/school_year.dart';
import '../models/dashboard_data.dart';

/// Calls the aggregate endpoints backing the Dashboard's stat cards, spread
/// across student-service and enrollment-service (see handoff doc — there is
/// no API gateway, so each service is called on its own Dio client).
class DashboardApi {
  DashboardApi({required Dio studentClient, required Dio enrollmentClient})
      : _student = studentClient,
        _enrollment = enrollmentClient;

  final Dio _student;
  final Dio _enrollment;

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
      _count(
        _enrollment,
        '/api/enrollments/',
        query: {'enrollment_status': 'pending', 'school_year': sy},
      ),
    ]);

    return DashboardStats(
      schoolYear: sy,
      totalStudents: results[0],
      activeStudents: results[1],
      enrolledThisYear: results[2],
      pendingEnrollment: results[3],
    );
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
    required this.pendingEnrollment,
  });

  final String schoolYear;
  final int totalStudents;
  final int activeStudents;
  final int enrolledThisYear;
  final int pendingEnrollment;
}
