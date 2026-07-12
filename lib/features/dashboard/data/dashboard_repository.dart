import 'package:flutter/foundation.dart';

import '../models/dashboard_data.dart';
import 'dashboard_api.dart';

/// Static Announcements & Forms feed. No backend model/endpoint exists for
/// this yet (see handoff doc) — kept as placeholder content until a real
/// announcements endpoint is added to enrollment-service or a shared service.
const _placeholderAnnouncements = [
  Announcement(
    category: AnnouncementCategory.enrollment,
    title: 'Enrollment period closes July 15',
    relativeTime: '2 hours ago',
  ),
  Announcement(
    category: AnnouncementCategory.form,
    title: 'New SF10 form template uploaded',
    relativeTime: '1 day ago',
  ),
  Announcement(
    category: AnnouncementCategory.deadline,
    title: 'Grade submission deadline: July 20',
    relativeTime: '2 days ago',
  ),
];

/// Provides Dashboard data. Stat cards and today's attendance are fetched
/// live from student-service / enrollment-service via [DashboardApi];
/// Announcements & Forms has no backing endpoint yet, so it stays static.
class DashboardRepository {
  DashboardRepository(this._api);

  final DashboardApi _api;

  static const _fallbackStats = DashboardStats(
    schoolYear: '2025-2026',
    totalStudents: 1248,
    activeStudents: 1190,
    enrolledThisYear: 1190,
    pendingEnrollment: 34,
  );
  static const _fallbackAttendance = AttendanceBreakdown(present: 1102, late: 30, absent: 58);

  Future<DashboardData> fetch() async {
    final now = DateTime.now();

    // Stats and attendance come from different endpoints (student-service vs.
    // enrollment-service) — fetch them independently so one failing endpoint
    // (e.g. attendance/summary for a role IsAdvisoryTeacherOrStaff blocks)
    // doesn't blank out stats that are already working. Each failure falls
    // back to sample data so the layout still renders, but callers must be
    // told via statsAreLive/attendanceIsLive rather than silently treating
    // the fallback as real — the old version had no error surface at all.
    var statsAreLive = true;
    final stats = await _api.fetchStats().catchError((error, stackTrace) {
      debugPrint('DashboardApi.fetchStats failed, using sample data: $error\n$stackTrace');
      statsAreLive = false;
      return _fallbackStats;
    });
    var attendanceIsLive = true;
    final attendance = await _api.fetchTodayAttendance(now).catchError((error, stackTrace) {
      debugPrint('DashboardApi.fetchTodayAttendance failed, using sample data: $error\n$stackTrace');
      attendanceIsLive = false;
      return _fallbackAttendance;
    });

    return DashboardData(
      schoolYear: 'S.Y. ${stats.schoolYear}',
      totalStudents: stats.totalStudents,
      activeStudents: stats.activeStudents,
      enrolledThisYear: stats.enrolledThisYear,
      pendingEnrollment: stats.pendingEnrollment,
      attendance: attendance,
      announcements: _placeholderAnnouncements,
      statsAreLive: statsAreLive,
      attendanceIsLive: attendanceIsLive,
    );
  }
}
