import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/roles.dart';
import '../../../core/theme/app_theme.dart';
import '../../advisory/state/advisory_provider.dart';
import '../../auth/state/auth_provider.dart';
import '../../shell/ui/app_shell.dart';
import '../data/dashboard_repository.dart';
import '../models/dashboard_data.dart';
import 'widgets/announcements_card.dart';
import 'widgets/attendance_card.dart';
import 'widgets/financial_snapshot_card.dart';
import 'widgets/needs_attention_card.dart';
import 'widgets/pending_enrollment_card.dart';
import 'widgets/staff_overview_card.dart';
import 'widgets/stat_card.dart';
import 'widgets/system_health_card.dart';
import 'widgets/todays_classes_card.dart';

/// Dashboard tab: shows a different card set per role (teacher, registrar,
/// admin, super_admin, accounting) per the design mock, while sharing the
/// AppBar and pull-to-refresh shell across all of them. All stat-card data
/// is explicitly deferred per the RBAC handoff — role-specific placeholder
/// figures are used until the real endpoints ship.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.repository,
    required this.onNavigateToTab,
  });

  final DashboardRepository repository;
  final ValueChanged<ShellTab> onNavigateToTab;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<DashboardData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = widget.repository.fetch();
  }

  Future<void> _refresh() async {
    final data = await widget.repository.fetch();
    setState(() => _dataFuture = Future.value(data));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final today = DateTime.now();

    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 74,
        title: FutureBuilder<DashboardData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            final schoolYear = snapshot.data?.schoolYear ?? '';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$schoolYear · ${DateFormat('EEE, MMMM d').format(today)}',
                  style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted3),
                ),
                const SizedBox(height: 2),
                Text(
                  'Dashboard',
                  style: GoogleFonts.dmSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.headingDark,
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.avatarGradientStart, AppColors.avatarGradientEnd],
                  ),
                ),
                child: Center(
                  child: Text(
                    user?.initials ?? '?',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<DashboardData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final role = user?.role ?? '';
          // super_admin/accounting bodies don't read live stats/attendance at
          // all, so the notice would be noise for them.
          final showsLiveData = role != roleSuperAdmin && role != roleAccounting;
          final isStale = showsLiveData && (!data.statsAreLive || !data.attendanceIsLive);
          return RefreshIndicator(
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.dashboardScreenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isStale) ...[
                    const _StaleDataBanner(),
                    const SizedBox(height: AppSpacing.interCardGap),
                  ],
                  _buildBodyForRole(role, data, today),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBodyForRole(String role, DashboardData data, DateTime today) {
    switch (role) {
      case roleTeacher:
        return _TeacherBody(
          data: data,
          onOpenAttendance: () => widget.onNavigateToTab(ShellTab.attendance),
          onOpenGrades: () => widget.onNavigateToTab(ShellTab.grades),
        );
      case roleSuperAdmin:
        return const _SuperAdminBody();
      case roleRegistrar:
        return _RegistrarBody(data: data, today: today);
      case roleAdmin:
        return _StaffBody(data: data, today: today);
      case roleAccounting:
        return const _AccountingBody();
      default:
        return _StaffBody(data: data, today: today);
    }
  }
}

/// Shown when a stat or attendance fetch failed and the Dashboard is
/// displaying hardcoded fallback figures instead of live data — without
/// this, a fetch failure was previously invisible to the user (see
/// DashboardRepository.fetch).
class _StaleDataBanner extends StatelessWidget {
  const _StaleDataBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
        border: Border.all(color: AppColors.warningText.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, size: 16, color: AppColors.warningText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Couldn't reach the server — showing sample figures. Pull to refresh to retry.",
              style: GoogleFonts.dmSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.warningText),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherBody extends StatelessWidget {
  const _TeacherBody({required this.data, required this.onOpenAttendance, required this.onOpenGrades});

  final DashboardData data;
  final VoidCallback onOpenAttendance;
  final VoidCallback onOpenGrades;

  @override
  Widget build(BuildContext context) {
    final advisory = context.watch<AdvisoryProvider>();
    final sectionCount = advisory.advisories.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (advisory.advisories.isNotEmpty)
          TodaysClassesCard(
            sections: advisory.advisories,
            onOpenAttendance: onOpenAttendance,
            onOpenGrades: onOpenGrades,
          ),
        const SizedBox(height: AppSpacing.interCardGap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: StatCard(
                label: 'My Sections',
                value: '$sectionCount',
                icon: Icons.groups_outlined,
                pill: StatPill(
                  label: 'S.Y. ${data.schoolYear.replaceFirst('S.Y. ', '')}',
                  background: AppColors.neutralPillBg,
                  textColor: AppColors.neutralPillText,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.statGridGap),
            Expanded(
              child: StatCard(
                label: 'Week Attendance Avg',
                value: '${data.attendance.ratePercent}%',
                icon: Icons.trending_up,
                pill: StatPill(
                  label: 'this week',
                  background: AppColors.successBg,
                  textColor: AppColors.successText,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StaffBody extends StatelessWidget {
  const _StaffBody({required this.data, required this.today});

  final DashboardData data;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const NeedsAttentionCard(
          items: [
            AttentionItem(icon: Icons.receipt_long_outlined, title: 'Unpaid invoices', count: 18),
            AttentionItem(icon: Icons.people_outline, title: 'Pending enrollment approvals', count: 34),
          ],
        ),
        const SizedBox(height: AppSpacing.interCardGap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: StatCard(
                label: 'Active Students',
                value: '${data.activeStudents}',
                icon: Icons.groups_outlined,
                pill: StatPill(label: 'as of today', background: AppColors.neutralPillBg, textColor: AppColors.neutralPillText),
              ),
            ),
            const SizedBox(width: AppSpacing.statGridGap),
            Expanded(
              child: StatCard(
                label: 'Enrolled This Year',
                value: '${data.enrolledThisYear}',
                icon: Icons.calendar_month_outlined,
                pill: StatPill(label: data.schoolYear, background: AppColors.neutralPillBg, textColor: AppColors.neutralPillText),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.statGridGap),
        PendingEnrollmentCard(value: data.pendingEnrollment),
        const SizedBox(height: AppSpacing.interCardGap),
        const FinancialSnapshotCard(),
        const SizedBox(height: AppSpacing.interCardGap),
        AttendanceCard(attendance: data.attendance, date: today),
        const SizedBox(height: AppSpacing.interCardGap),
        AnnouncementsCard(announcements: data.announcements),
      ],
    );
  }
}

/// Registrar sees the same academic/enrollment stats as admin, but no
/// billing content — the backend's BILLING_ROLES (super_admin/admin/
/// accounting) excludes registrar entirely, confirmed in billing/views.py
/// and the admin-portal sidebar, which never surfaces Financial Snapshot or
/// Invoices/Payments to registrar.
class _RegistrarBody extends StatelessWidget {
  const _RegistrarBody({required this.data, required this.today});

  final DashboardData data;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const NeedsAttentionCard(
          items: [
            AttentionItem(icon: Icons.people_outline, title: 'Pending enrollment approvals', count: 34),
          ],
        ),
        const SizedBox(height: AppSpacing.interCardGap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: StatCard(
                label: 'Active Students',
                value: '${data.activeStudents}',
                icon: Icons.groups_outlined,
                pill: StatPill(label: 'as of today', background: AppColors.neutralPillBg, textColor: AppColors.neutralPillText),
              ),
            ),
            const SizedBox(width: AppSpacing.statGridGap),
            Expanded(
              child: StatCard(
                label: 'Enrolled This Year',
                value: '${data.enrolledThisYear}',
                icon: Icons.calendar_month_outlined,
                pill: StatPill(label: data.schoolYear, background: AppColors.neutralPillBg, textColor: AppColors.neutralPillText),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.statGridGap),
        PendingEnrollmentCard(value: data.pendingEnrollment),
        const SizedBox(height: AppSpacing.interCardGap),
        AttendanceCard(attendance: data.attendance, date: today),
        const SizedBox(height: AppSpacing.interCardGap),
        AnnouncementsCard(announcements: data.announcements),
      ],
    );
  }
}

class _SuperAdminBody extends StatelessWidget {
  const _SuperAdminBody();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SystemHealthCard(activeSessions: 57),
        SizedBox(height: AppSpacing.interCardGap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: StatCard(
                label: 'Teacher Accounts',
                value: '42',
                icon: Icons.school_outlined,
                pill: StatPill(label: 'active', background: AppColors.neutralPillBg, textColor: AppColors.neutralPillText),
              ),
            ),
            SizedBox(width: AppSpacing.statGridGap),
            Expanded(
              child: StatCard(
                label: 'Registrar/Admin',
                value: '9',
                icon: Icons.admin_panel_settings_outlined,
                pill: StatPill(label: 'active', background: AppColors.neutralPillBg, textColor: AppColors.neutralPillText),
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.interCardGap),
        StaffOverviewCard(teacherCount: 42, onLeaveCount: 3, noAdviserCount: 1),
        SizedBox(height: AppSpacing.interCardGap),
        FinancialSnapshotCard(),
        SizedBox(height: AppSpacing.interCardGap),
        NeedsAttentionCard(
          items: [
            AttentionItem(icon: Icons.people_outline, title: 'Pending enrollment approvals', count: 34),
          ],
        ),
      ],
    );
  }
}

class _AccountingBody extends StatelessWidget {
  const _AccountingBody();

  @override
  Widget build(BuildContext context) {
    // Accounting's RBAC scope is Billing-only (per the handoff's access
    // matrix), so its dashboard shows just the Financial Snapshot rather
    // than the student/enrollment stats staff roles see.
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [FinancialSnapshotCard()],
    );
  }
}
