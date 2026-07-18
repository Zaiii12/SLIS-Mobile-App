enum AnnouncementCategory { enrollment, form, deadline }

class Announcement {
  const Announcement({
    required this.category,
    required this.title,
    required this.relativeTime,
  });

  final AnnouncementCategory category;
  final String title;
  final String relativeTime;
}

class AttendanceBreakdown {
  const AttendanceBreakdown({
    required this.present,
    required this.late,
    required this.absent,
  });

  final int present;
  final int late;
  final int absent;

  int get total => present + late + absent;

  /// Attendance rate as a 0-100 rounded percentage, matching the mock's "92%" display.
  int get ratePercent => total == 0 ? 0 : ((present / total) * 100).round();
}

class DashboardData {
  const DashboardData({
    required this.schoolYear,
    required this.totalStudents,
    required this.activeStudents,
    required this.enrolledThisYear,
    required this.completedThisYear,
    required this.pendingEnrollment,
    required this.pendingEnrollmentByYear,
    required this.unpaidInvoices,
    required this.scholarshipCount,
    required this.attendance,
    required this.announcements,
    required this.statsAreLive,
    required this.attendanceIsLive,
    required this.unpaidInvoicesAreLive,
    required this.scholarshipCountIsLive,
  });

  final String schoolYear;
  final int totalStudents;
  final int activeStudents;
  final int enrolledThisYear;

  /// `enrollment_status=completed` count for the current school year — the
  /// Enrollment Funnel's "Completed" step (see DashboardApi.fetchStats).
  final int completedThisYear;
  final int pendingEnrollment;

  /// School year → pending count, across ALL years — see
  /// DashboardApi.fetchStats. Empty map if `statsAreLive` is false (the
  /// fallback sample data doesn't have a real per-year breakdown).
  final Map<String, int> pendingEnrollmentByYear;
  final int unpaidInvoices;

  /// Total `EnrollmentScholarship` rows (`GET /api/enrollment-scholarships/`
  /// count, unfiltered by year — see DashboardApi.fetchScholarshipCount).
  /// Only fetched for `staffAdmin` roles.
  final int scholarshipCount;
  final AttendanceBreakdown attendance;
  final List<Announcement> announcements;

  /// False when `fetchStats`/`fetchTodayAttendance` failed and the values
  /// above are the hardcoded fallback, not a live figure — the Dashboard UI
  /// uses this to show a visible notice instead of silently presenting
  /// sample data as real.
  final bool statsAreLive;
  final bool attendanceIsLive;
  final bool unpaidInvoicesAreLive;
  final bool scholarshipCountIsLive;

  /// Matches the ASIA web dashboard's `enrollmentRate` — enrolled ÷ total
  /// students, rounded. 0 when there are no students yet (avoids NaN).
  int get enrollmentRate =>
      totalStudents == 0 ? 0 : ((enrolledThisYear / totalStudents) * 100).round();
}
