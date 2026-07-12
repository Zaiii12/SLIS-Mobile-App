import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../attendance/data/attendance_repository.dart';
import '../../attendance/ui/attendance_screen.dart';
import '../../auth/state/auth_provider.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../dashboard/ui/dashboard_screen.dart';
import '../../grades/data/grades_repository.dart';
import '../../grades/ui/grades_screen.dart';
import '../../students/data/students_repository.dart';
import '../../students/ui/students_list_screen.dart';
import 'more_screen.dart';
import 'widgets/shell_bottom_nav_bar.dart';

enum ShellTab { dashboard, students, attendance, grades, more }

/// Tabs visible per role, in nav-bar order. `accounting` sees Dashboard and
/// More only; `guardian` sees nothing until backend scoping ships (handled
/// by [_visibleTabsForRole] returning an empty-feature list upstream of
/// this widget in practice, but kept here too as a defensive default).
List<ShellTab> _visibleTabsForRole(String role) {
  switch (role) {
    case 'accounting':
      return [ShellTab.dashboard, ShellTab.more];
    case 'teacher':
    case 'registrar':
    case 'admin':
    case 'super_admin':
      return ShellTab.values;
    default:
      return [ShellTab.dashboard, ShellTab.more];
  }
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
  });

  final DashboardRepository dashboardRepository;
  final StudentsRepository studentsRepository;
  final AttendanceRepository attendanceRepository;
  final GradesRepository gradesRepository;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  ShellTab _selected = ShellTab.dashboard;

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
            onNavigateToTab: (tab) => setState(() => _selected = tab),
          ),
          StudentsListScreen(repository: widget.studentsRepository),
          AttendanceScreen(repository: widget.attendanceRepository),
          GradesScreen(repository: widget.gradesRepository),
          const MoreScreen(),
        ],
      ),
      bottomNavigationBar: ShellBottomNavBar(
        selected: selected,
        visibleTabs: visibleTabs,
        onSelect: (tab) => setState(() => _selected = tab),
      ),
    );
  }
}
