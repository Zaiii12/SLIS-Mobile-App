import 'package:flutter/foundation.dart';

import '../../../core/auth/roles.dart';
import '../models/dashboard_data.dart';
import 'dashboard_api.dart';

/// Provides Dashboard data. Stat cards and today's attendance are fetched
/// live from student-service / enrollment-service via [DashboardApi].
class DashboardRepository {
  DashboardRepository(this._api);

  final DashboardApi _api;

  static const _fallbackStats = DashboardStats(
    schoolYear: '2025-2026',
    totalStudents: 1248,
    activeStudents: 1190,
    enrolledThisYear: 1190,
    completedThisYear: 0,
    pendingEnrollment: 34,
    pendingEnrollmentByYear: {'2025-2026': 34},
  );
  static const _fallbackAttendance = AttendanceBreakdown(
    present: 1102,
    late: 30,
    absent: 58,
  );
  static const _fallbackUnpaidInvoices = 18;
  static const _fallbackScholarshipCount = 12;

  Future<DashboardData> fetch({String? role, String? schoolYear}) async {
    final now = DateTime.now();

    // Stats, attendance, and unpaid invoices come from different endpoints
    // (student-service / enrollment-service / billing-service) — fetch them
    // independently so one failing endpoint (e.g. attendance/summary for a
    // role IsAdvisoryTeacherOrStaff blocks, or invoices/summary for a
    // non-billing role) doesn't blank out stats that are already working.
    // Each failure falls back to sample data so the layout still renders,
    // but callers must be told via statsAreLive/attendanceIsLive/
    // unpaidInvoicesAreLive rather than silently treating the fallback as
    // real — the old version had no error surface at all.
    var statsAreLive = true;
    final stats = await _api.fetchStats(schoolYear: schoolYear).catchError((
      error,
      stackTrace,
    ) {
      debugPrint(
        'DashboardApi.fetchStats failed, using sample data: $error\n$stackTrace',
      );
      statsAreLive = false;
      return _fallbackStats;
    });
    var attendanceIsLive = true;
    final attendance = await _api.fetchTodayAttendance(now).catchError((
      error,
      stackTrace,
    ) {
      debugPrint(
        'DashboardApi.fetchTodayAttendance failed, using sample data: $error\n$stackTrace',
      );
      attendanceIsLive = false;
      return _fallbackAttendance;
    });

    // Backend's BILLING_ROLES gate /api/invoices/summary/ to
    // super_admin/admin/accounting only — teacher/registrar always get
    // denied here, so skip the call entirely rather than surfacing an
    // expected 403 as "server unreachable".
    var unpaidInvoicesAreLive = true;
    int unpaidInvoices;
    if (hasAnyRole(role, billingRoles)) {
      unpaidInvoices = await _api.fetchUnpaidInvoiceCount().catchError((
        error,
        stackTrace,
      ) {
        debugPrint(
          'DashboardApi.fetchUnpaidInvoiceCount failed, using sample data: $error\n$stackTrace',
        );
        unpaidInvoicesAreLive = false;
        return _fallbackUnpaidInvoices;
      });
    } else {
      unpaidInvoices = _fallbackUnpaidInvoices;
    }

    // Scholarships Awarded: `GET /api/enrollment-scholarships/` is
    // `IsAdminRegistrarOrReadOnly` server-side (enrollment-service
    // `scholarships/views.py:40`) — any authenticated role can read, so
    // staffAdmin/registrar/accounting all see this stat; only teacher has no
    // real use for it (matches its dashboard body, which has no stat-card
    // row at all).
    var scholarshipCountIsLive = true;
    int scholarshipCount;
    if (role != roleTeacher) {
      scholarshipCount = await _api.fetchScholarshipCount().catchError((
        error,
        stackTrace,
      ) {
        debugPrint(
          'DashboardApi.fetchScholarshipCount failed, using sample data: $error\n$stackTrace',
        );
        scholarshipCountIsLive = false;
        return _fallbackScholarshipCount;
      });
    } else {
      scholarshipCount = _fallbackScholarshipCount;
    }

    return DashboardData(
      schoolYear: 'S.Y. ${stats.schoolYear}',
      totalStudents: stats.totalStudents,
      activeStudents: stats.activeStudents,
      enrolledThisYear: stats.enrolledThisYear,
      completedThisYear: stats.completedThisYear,
      pendingEnrollment: stats.pendingEnrollment,
      pendingEnrollmentByYear: stats.pendingEnrollmentByYear,
      unpaidInvoices: unpaidInvoices,
      scholarshipCount: scholarshipCount,
      attendance: attendance,
      statsAreLive: statsAreLive,
      attendanceIsLive: attendanceIsLive,
      unpaidInvoicesAreLive: unpaidInvoicesAreLive,
      scholarshipCountIsLive: scholarshipCountIsLive,
    );
  }
}
