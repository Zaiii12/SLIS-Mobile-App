import 'package:dio/dio.dart';

import '../../dashboard/models/dashboard_data.dart';
import '../models/attendance_status.dart';
import '../models/roster_entry.dart';

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// Calls enrollment-service's attendance and enrollment endpoints per the
/// RBAC handoff. All attendance read/write endpoints are gated server-side
/// by `IsAdvisoryTeacherOrStaff`; `/summary/` is read-open to any
/// authenticated user.
class AttendanceApi {
  AttendanceApi(this._enrollment);

  final Dio _enrollment;

  Future<AttendanceBreakdown> fetchSummary(DateTime date) async {
    final response = await _enrollment.get(
      '/api/attendance/summary/',
      queryParameters: {'date': _isoDate(date)},
    );
    final data = response.data as Map<String, dynamic>;
    return AttendanceBreakdown(
      present: data['present'] as int? ?? 0,
      late: data['late'] as int? ?? 0,
      absent: data['absent'] as int? ?? 0,
    );
  }

  Future<List<RosterEntry>> fetchRoster(int sectionAdvisoryId) async {
    final response = await _enrollment.get(
      '/api/enrollments/',
      queryParameters: {'section_advisory': sectionAdvisoryId},
    );
    final data = response.data;
    final results = data is Map<String, dynamic> ? data['results'] as List? : data as List?;
    return (results ?? []).cast<Map<String, dynamic>>().map(RosterEntry.fromJson).toList();
  }

  /// Existing attendance records for a section/date, keyed by enrollment id
  /// server-side — used to pre-populate the roster before submission.
  Future<Map<int, AttendanceStatus>> fetchExisting({
    required int sectionAdvisoryId,
    required DateTime date,
  }) async {
    final response = await _enrollment.get(
      '/api/attendance/',
      queryParameters: {
        'section_advisory': sectionAdvisoryId,
        'date': _isoDate(date),
      },
    );
    final data = response.data;
    final results = data is Map<String, dynamic> ? data['results'] as List? : data as List?;
    final marks = <int, AttendanceStatus>{};
    for (final row in (results ?? []).cast<Map<String, dynamic>>()) {
      final enrollmentId = row['enrollment'] as int;
      marks[enrollmentId] = AttendanceStatusJson.fromJson(row['status'] as String? ?? 'present');
    }
    return marks;
  }

  Future<void> submitBulk({
    required Map<int, AttendanceStatus> marks,
    required DateTime date,
  }) async {
    final isoDate = _isoDate(date);
    await _enrollment.post(
      '/api/attendance/bulk/',
      data: [
        for (final entry in marks.entries)
          {
            'enrollment': entry.key,
            'date': isoDate,
            'status': entry.value.toJson(),
          },
      ],
    );
  }
}
