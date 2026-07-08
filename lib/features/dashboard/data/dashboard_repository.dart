import '../models/dashboard_data.dart';

/// Provides Dashboard data. No ASIA backend endpoint for these aggregate
/// stats has been confirmed yet (see plan's Open Questions), so [fetch]
/// currently returns static sample data shaped like the design mock. This
/// method is the single seam to swap in a real HTTP call once the endpoint
/// is available — callers (DashboardScreen) don't need to change.
class DashboardRepository {
  Future<DashboardData> fetch() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    return const DashboardData(
      schoolYear: 'S.Y. 2025-2026',
      totalStudents: 1248,
      activeStudents: 1190,
      enrolledThisYear: 1190,
      pendingEnrollment: 34,
      attendance: AttendanceBreakdown(present: 1102, late: 30, absent: 58),
      announcements: [
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
      ],
    );
  }
}
