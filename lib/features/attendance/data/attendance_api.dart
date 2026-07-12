import 'package:dio/dio.dart';

import '../../advisory/models/section_advisory.dart';
import '../../dashboard/models/dashboard_data.dart';
import '../../grades/models/grading_template.dart' show schoolLevelToJson;
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

  /// Per `attendance/views.py`'s `summary` action: takes `date_from`/
  /// `date_to` (a single day is both set to the same date) and returns
  /// counts nested under `totals`, not as flat top-level fields.
  Future<AttendanceBreakdown> fetchSummary(DateTime date) async {
    final isoDate = _isoDate(date);
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

  /// There is no `section_advisory` filter on `/api/enrollments/` — a
  /// `SectionAdvisory` is really just a saved (school_year, school_level,
  /// grade_level, section[, strand]) tuple (see `teacher_student_ids()` in
  /// the backend's permissions module), so the roster is scoped by matching
  /// those fields directly via `EnrollmentFilter`.
  Future<List<RosterEntry>> fetchRoster(SectionAdvisory section) async {
    final response = await _enrollment.get(
      '/api/enrollments/',
      queryParameters: {
        'school_year': section.schoolYear,
        'school_level': schoolLevelToJson(section.schoolLevel),
        'grade_level': section.gradeLevel,
        'section': section.section,
        if (section.strand != null) 'strand': section.strand,
      },
    );
    final data = response.data;
    final results = data is Map<String, dynamic> ? data['results'] as List? : data as List?;
    return (results ?? []).cast<Map<String, dynamic>>().map(RosterEntry.fromJson).toList();
  }

  /// Existing attendance records for a section/date, keyed by enrollment id
  /// server-side — used to pre-populate the roster before submission. Scoped
  /// via `enrollment__school_year`/`grade_level`/`section` (confirmed
  /// `filterset_fields` on `AttendanceViewSet`) since there is no
  /// `section_advisory` filter.
  Future<Map<int, AttendanceStatus>> fetchExisting({
    required SectionAdvisory section,
    required DateTime date,
  }) async {
    final response = await _enrollment.get(
      '/api/attendance/',
      queryParameters: {
        'enrollment__school_year': section.schoolYear,
        'enrollment__grade_level': section.gradeLevel,
        'enrollment__section': section.section,
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

  /// Per `attendance/views.py`'s `bulk` action: a single `date` plus a
  /// `records` list of `{enrollment_id, status}` — not a bare array of
  /// per-record `{enrollment, date, status}` objects.
  Future<void> submitBulk({
    required Map<int, AttendanceStatus> marks,
    required DateTime date,
  }) async {
    await _enrollment.post(
      '/api/attendance/bulk/',
      data: {
        'date': _isoDate(date),
        'records': [
          for (final entry in marks.entries)
            {'enrollment_id': entry.key, 'status': entry.value.toJson()},
        ],
      },
    );
  }
}
