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
    required this.pendingEnrollment,
    required this.attendance,
    required this.announcements,
  });

  final String schoolYear;
  final int totalStudents;
  final int activeStudents;
  final int enrolledThisYear;
  final int pendingEnrollment;
  final AttendanceBreakdown attendance;
  final List<Announcement> announcements;
}
