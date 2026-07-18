import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/roles.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/ui/attendance_screen.dart';
import '../../auth/state/auth_provider.dart';
import '../../billing/data/billing_repository.dart';
import '../../billing/data/enrollment_repository.dart';
import '../../billing/ui/enrollments_list_screen.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../dashboard/ui/dashboard_screen.dart';
import '../../dashboard/ui/financial_stats_screen.dart';
import '../../advisory/data/advisory_api.dart';
import '../../grades/data/grades_repository.dart';
import '../../grades/ui/grade_overview_screen.dart';
import '../../grades/ui/grades_screen.dart';
import '../../monitoring/data/audit_log_repository.dart';
import '../../monitoring/data/teachers_repository.dart';
import '../../monitoring/ui/audit_log_screen.dart';
import '../../monitoring/ui/monitoring_screen.dart';
import '../../students/data/students_repository.dart';
import '../../students/ui/students_list_screen.dart';
import 'more_screen.dart';
import 'widgets/shell_bottom_nav_bar.dart';

enum ShellTab {
  dashboard,
  students,
  attendance,
  grades,
  gradeOverview,
  enrollments,
  monitoring,
  auditLog,
  financialStats,
  more,
}

/// Tabs visible per role, in nav-bar order. Students is read access for any
/// authenticated role (matching the backend's `IsAdminRegistrarOrReadOnly`),
/// so every role — including `accounting` — sees Dashboard+Students+More.
/// `admin`/`super_admin` get Monitoring instead of Attendance+Grades: those
/// two roles get every section school-wide (see `AdvisoryProvider`), and
/// `GET /api/auth/users/` backing the teacher picker is gated to exactly
/// this pair server-side (`ADMIN_ROLES` in `accounts/audit.py` — notably
/// excludes `registrar`), so Monitoring can't be offered to registrar.
/// Audit Log and Financial Stats are `staffAdmin`-only for the same reason:
/// `GET /api/auth/audit-logs/` is gated to `ADMIN_ROLES` server-side, and
/// financial-summary is view-only staff data, not something registrar or
/// teacher have any backend access to.
/// `teacher` keeps the original Attendance+Grades tabs (their own advisory
/// roster, editable). `registrar` gets Grade Overview instead — a read-only,
/// school-wide grade summary (see `GradeOverviewScreen`) — and no Attendance
/// tab at all (out of scope per product decision, not a backend gap).
/// `registrar` also gets Enrollments — read + quick-edit of section/status
/// (see `EnrollmentsListScreen`); full enrollment intake stays web-only.
/// Unknown roles (including `guardian`, which is dead on the backend) fall
/// back to the same Dashboard+Students+More default.
List<ShellTab> _visibleTabsForRole(String role) {
  final tabs = [ShellTab.dashboard, ShellTab.students];
  if (hasAnyRole(role, staffAdmin)) {
    tabs.addAll([ShellTab.monitoring, ShellTab.auditLog, ShellTab.financialStats]);
  } else if (role == roleTeacher) {
    tabs.addAll([ShellTab.attendance, ShellTab.grades]);
  } else if (role == roleRegistrar) {
    tabs.addAll([ShellTab.enrollments, ShellTab.gradeOverview]);
  }
  tabs.add(ShellTab.more);
  return tabs;
}

/// Owns the single persistent bottom nav bar and swaps tab bodies via
/// [IndexedStack] so each tab keeps its scroll position/state when the user
/// switches away and back. Replaces the old pattern of pushing a full-screen
/// route per tab.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.dashboardRepository,
    required this.studentsRepository,
    required this.attendanceRepository,
    required this.gradesRepository,
    required this.teachersRepository,
    required this.advisoryApi,
    required this.billingRepository,
    required this.enrollmentRepository,
    required this.auditLogRepository,
  });

  final DashboardRepository dashboardRepository;
  final StudentsRepository studentsRepository;
  final AttendanceRepository attendanceRepository;
  final GradesRepository gradesRepository;
  final TeachersRepository teachersRepository;
  final AdvisoryApi advisoryApi;
  final BillingRepository billingRepository;
  final EnrollmentRepository enrollmentRepository;
  final AuditLogRepository auditLogRepository;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  ShellTab _selected = ShellTab.dashboard;

  /// Tabs the user has actually switched to at least once. A tab's screen
  /// isn't built (and so doesn't fire its `initState` fetch) until it's in
  /// this set — an `IndexedStack` alone would build all 5 tabs up front
  /// regardless of role visibility, firing e.g. Students/Attendance/Grades
  /// fetches for an `accounting`/`guardian` user who can never navigate to
  /// them. Dashboard is always visited first, so it seeds the set.
  final Set<ShellTab> _visited = {ShellTab.dashboard};

  void _select(ShellTab tab) {
    setState(() {
      _selected = tab;
      _visited.add(tab);
    });
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().user?.role ?? '';
    final visibleTabs = _visibleTabsForRole(role);

    // If a role change (or restored session) makes the current tab
    // unavailable, fall back to Dashboard rather than rendering nothing.
    final selected = visibleTabs.contains(_selected) ? _selected : ShellTab.dashboard;

    return Scaffold(
      body: IndexedStack(
        index: ShellTab.values.indexOf(selected),
        children: [
          DashboardScreen(
            repository: widget.dashboardRepository,
            onNavigateToTab: _select,
          ),
          if (_visited.contains(ShellTab.students))
            StudentsListScreen(repository: widget.studentsRepository)
          else
            const SizedBox.shrink(),
          if (_visited.contains(ShellTab.attendance))
            AttendanceScreen(repository: widget.attendanceRepository)
          else
            const SizedBox.shrink(),
          if (_visited.contains(ShellTab.grades))
            GradesScreen(repository: widget.gradesRepository)
          else
            const SizedBox.shrink(),
          if (_visited.contains(ShellTab.gradeOverview))
            GradeOverviewScreen(repository: widget.enrollmentRepository)
          else
            const SizedBox.shrink(),
          if (_visited.contains(ShellTab.enrollments))
            EnrollmentsListScreen(repository: widget.enrollmentRepository)
          else
            const SizedBox.shrink(),
          if (_visited.contains(ShellTab.monitoring))
            MonitoringScreen(
              teachersRepository: widget.teachersRepository,
              advisoryApi: widget.advisoryApi,
              attendanceRepository: widget.attendanceRepository,
              gradesRepository: widget.gradesRepository,
            )
          else
            const SizedBox.shrink(),
          if (_visited.contains(ShellTab.auditLog))
            AuditLogScreen(repository: widget.auditLogRepository)
          else
            const SizedBox.shrink(),
          if (_visited.contains(ShellTab.financialStats))
            FinancialStatsScreen(repository: widget.billingRepository)
          else
            const SizedBox.shrink(),
          if (_visited.contains(ShellTab.more)) const MoreScreen() else const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: ShellBottomNavBar(
        selected: selected,
        visibleTabs: visibleTabs,
        onSelect: _select,
      ),
    );
  }
}
