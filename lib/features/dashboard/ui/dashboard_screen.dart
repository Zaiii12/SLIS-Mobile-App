import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/roles.dart';
import '../../../core/theme/app_theme.dart';
import '../../advisory/state/advisory_provider.dart';
import '../../auth/state/auth_provider.dart';
import '../../billing/data/billing_repository.dart';
import '../../billing/data/enrollment_repository.dart';
import '../../billing/ui/pending_enrollment_screen.dart';
import '../../billing/ui/unpaid_invoices_list_screen.dart';
import '../../shell/ui/app_shell.dart';
import '../../students/data/students_repository.dart';
import '../../students/models/student.dart';
import '../data/dashboard_repository.dart';
import '../models/dashboard_data.dart';
import '../models/recent_enrollment.dart';
import 'widgets/enrollment_funnel_card.dart';
import 'widgets/needs_attention_card.dart';
import 'widgets/pending_enrollment_card.dart';
import 'widgets/recent_enrollments_card.dart';
import 'widgets/recent_students_card.dart';
import 'widgets/stat_card.dart';
import 'widgets/todays_classes_card.dart';

/// Dashboard tab: shows a different card set per role (teacher, registrar,
/// admin, super_admin, accounting) per the design mock, while sharing the
/// AppBar and pull-to-refresh shell across all of them.
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
    _dataFuture = widget.repository.fetch(
      role: context.read<AuthProvider>().user?.role,
    );
  }

  Future<void> _refresh() async {
    final data = await widget.repository.fetch(
      role: context.read<AuthProvider>().user?.role,
    );
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
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppColors.textMuted3,
                  ),
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
                    colors: [
                      AppColors.avatarGradientStart,
                      AppColors.avatarGradientEnd,
                    ],
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
          // The accounting body renders no live stats/attendance figures at
          // all (`_AccountingBody` is an empty placeholder), so the notice
          // would be noise there. Every other role's body — including
          // super_admin/admin's 4-stat row — reads real `data` fields.
          final showsLiveData = role != roleAccounting;
          // Only bodies with billing access display the unpaid invoice
          // count — teacher/registrar have no billing access at all
          // (backend's BILLING_ROLES excludes them) and never render this
          // figure, so a failed invoice fetch for them isn't real staleness.
          final showsUnpaidInvoices =
              role != roleTeacher && role != roleRegistrar;
          // Scholarships Awarded is staffAdmin-only (see DashboardRepository).
          final showsScholarshipCount = hasAnyRole(role, staffAdmin);
          final isStale =
              showsLiveData &&
              (!data.statsAreLive ||
                  !data.attendanceIsLive ||
                  (showsUnpaidInvoices && !data.unpaidInvoicesAreLive) ||
                  (showsScholarshipCount && !data.scholarshipCountIsLive));
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
                  _buildBodyForRole(role, data),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBodyForRole(String role, DashboardData data) {
    switch (role) {
      case roleTeacher:
        return _TeacherBody(
          data: data,
          onOpenAttendance: () => widget.onNavigateToTab(ShellTab.attendance),
          onOpenGrades: () => widget.onNavigateToTab(ShellTab.grades),
        );
      case roleSuperAdmin:
      case roleAdmin:
        return _SuperAdminBody(data: data);
      case roleRegistrar:
        return _RegistrarBody(data: data);
      case roleAccounting:
        return const _AccountingBody();
      default:
        return _StaffBody(data: data);
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
              style: GoogleFonts.dmSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.warningText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherBody extends StatelessWidget {
  const _TeacherBody({
    required this.data,
    required this.onOpenAttendance,
    required this.onOpenGrades,
  });

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
  const _StaffBody({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final billingRepository = context.read<BillingRepository>();
    final enrollmentRepository = context.read<EnrollmentRepository>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NeedsAttentionCard(
          items: [
            AttentionItem(
              icon: Icons.receipt_long_outlined,
              title: 'Unpaid invoices',
              count: data.unpaidInvoices,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      UnpaidInvoicesListScreen(repository: billingRepository),
                ),
              ),
            ),
            AttentionItem(
              icon: Icons.people_outline,
              title: 'Pending enrollment approvals',
              count: data.pendingEnrollment,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      PendingEnrollmentScreen(repository: enrollmentRepository),
                ),
              ),
            ),
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
                pill: StatPill(
                  label: 'as of today',
                  background: AppColors.neutralPillBg,
                  textColor: AppColors.neutralPillText,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.statGridGap),
            Expanded(
              child: StatCard(
                label: 'Enrolled This Year',
                value: '${data.enrolledThisYear}',
                icon: Icons.calendar_month_outlined,
                pill: StatPill(
                  label: data.schoolYear,
                  background: AppColors.neutralPillBg,
                  textColor: AppColors.neutralPillText,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.statGridGap),
        PendingEnrollmentCard(
          value: data.pendingEnrollment,
          byYear: data.pendingEnrollmentByYear,
        ),
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
  const _RegistrarBody({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final enrollmentRepository = context.read<EnrollmentRepository>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NeedsAttentionCard(
          items: [
            AttentionItem(
              icon: Icons.people_outline,
              title: 'Pending enrollment approvals',
              count: data.pendingEnrollment,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      PendingEnrollmentScreen(repository: enrollmentRepository),
                ),
              ),
            ),
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
                pill: StatPill(
                  label: 'as of today',
                  background: AppColors.neutralPillBg,
                  textColor: AppColors.neutralPillText,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.statGridGap),
            Expanded(
              child: StatCard(
                label: 'Enrolled This Year',
                value: '${data.enrolledThisYear}',
                icon: Icons.calendar_month_outlined,
                pill: StatPill(
                  label: data.schoolYear,
                  background: AppColors.neutralPillBg,
                  textColor: AppColors.neutralPillText,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.statGridGap),
        PendingEnrollmentCard(
          value: data.pendingEnrollment,
          byYear: data.pendingEnrollmentByYear,
        ),
      ],
    );
  }
}

/// Audit monitoring and financial stats moved to their own bottom-nav tabs
/// (see `AppShell`/`ShellTab.auditLog`/`ShellTab.financialStats`) — this
/// body leads with the same 4-stat row as the real ASIA web admin dashboard
/// (`DashboardPage.jsx`: Total Students / Enrolled This S.Y. / Pending
/// Enrollment / Scholarships Awarded — first 3 already existed on
/// `DashboardData`, Scholarships Awarded added via
/// `DashboardApi.fetchScholarshipCount`). SystemHealthCard and
/// StaffOverviewCard were both removed entirely (2026-07-18) since neither
/// had a real backing endpoint anywhere in ASIA. Also adds two real-data
/// cards: Recent Enrollments (`GET /api/enrollments/?ordering=-enrollment_id`,
/// any status) and Recently Added Students
/// (`GET /api/students/?ordering=-student_id`) — both use the
/// auto-incrementing PK as a newest-first proxy since neither model has a
/// creation timestamp. StaffOverviewCard was removed entirely (2026-07-18)
/// since it had no real backing endpoint at all.
class _SuperAdminBody extends StatefulWidget {
  const _SuperAdminBody({required this.data});

  final DashboardData data;

  @override
  State<_SuperAdminBody> createState() => _SuperAdminBodyState();
}

class _SuperAdminBodyState extends State<_SuperAdminBody> {
  late Future<List<RecentEnrollment>> _recentEnrollmentsFuture;
  late Future<List<Student>> _recentStudentsFuture;

  @override
  void initState() {
    super.initState();
    _recentEnrollmentsFuture =
        context.read<EnrollmentRepository>().fetchRecentEnrollments();
    _recentStudentsFuture =
        context.read<StudentsRepository>().fetchRecentStudents();
  }

  @override
  Widget build(BuildContext context) {
    final enrollmentRepository = context.read<EnrollmentRepository>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: StatCard(
                label: 'Total Students',
                value: '${widget.data.totalStudents}',
                icon: Icons.groups_outlined,
                pill: StatPill(
                  label: '${widget.data.activeStudents} active',
                  background: AppColors.successBg,
                  textColor: AppColors.successText,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.statGridGap),
            Expanded(
              child: StatCard(
                label: 'Enrolled This S.Y.',
                value: '${widget.data.enrolledThisYear}',
                icon: Icons.calendar_month_outlined,
                pill: StatPill(
                  label: widget.data.schoolYear,
                  background: AppColors.neutralPillBg,
                  textColor: AppColors.neutralPillText,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.statGridGap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: StatCard(
                label: 'Pending Enrollment',
                value: '${widget.data.pendingEnrollment}',
                icon: Icons.assignment_outlined,
                pill: StatPill(
                  label: widget.data.pendingEnrollment > 0 ? 'needs action' : 'all clear',
                  background: widget.data.pendingEnrollment > 0
                      ? AppColors.dangerBg
                      : AppColors.successBg,
                  textColor: widget.data.pendingEnrollment > 0
                      ? AppColors.dangerText
                      : AppColors.successText,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.statGridGap),
            Expanded(
              child: StatCard(
                label: 'Scholarships Awarded',
                value: '${widget.data.scholarshipCount}',
                icon: Icons.emoji_events_outlined,
                pill: StatPill(
                  label: widget.data.schoolYear,
                  background: AppColors.infoBlueBg,
                  textColor: AppColors.infoBlueIcon,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.interCardGap),
        EnrollmentFunnelCard(
          schoolYear: widget.data.schoolYear,
          pendingCount: widget.data.pendingEnrollment,
          enrolledCount: widget.data.enrolledThisYear,
          completedCount: widget.data.completedThisYear,
          enrollmentRate: widget.data.enrollmentRate,
        ),
        const SizedBox(height: AppSpacing.interCardGap),
        NeedsAttentionCard(
          items: [
            AttentionItem(
              icon: Icons.people_outline,
              title: 'Pending enrollment approvals',
              count: widget.data.pendingEnrollment,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      PendingEnrollmentScreen(repository: enrollmentRepository),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.interCardGap),
        FutureBuilder<List<RecentEnrollment>>(
          future: _recentEnrollmentsFuture,
          builder: (context, snapshot) {
            return RecentEnrollmentsCard(enrollments: snapshot.data ?? const []);
          },
        ),
        const SizedBox(height: AppSpacing.interCardGap),
        FutureBuilder<List<Student>>(
          future: _recentStudentsFuture,
          builder: (context, snapshot) {
            return RecentStudentsCard(students: snapshot.data ?? const []);
          },
        ),
      ],
    );
  }
}

class _AccountingBody extends StatelessWidget {
  const _AccountingBody();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [],
    );
  }
}
