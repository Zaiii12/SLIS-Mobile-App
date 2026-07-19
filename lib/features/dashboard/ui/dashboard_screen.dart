import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/roles.dart';
import '../../../core/theme/app_theme.dart';
import '../../advisory/models/section_advisory.dart';
import '../../advisory/state/advisory_provider.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../auth/state/auth_provider.dart';
import '../../billing/data/billing_repository.dart';
import '../../billing/data/enrollment_repository.dart';
import '../../billing/models/invoice.dart';
import '../../billing/ui/billing_format.dart';
import '../../billing/ui/pending_enrollment_screen.dart';
import '../../billing/ui/unpaid_invoices_list_screen.dart';
import '../../settings/state/school_year_provider.dart';
import '../../shell/ui/app_shell.dart';
import '../../shell/ui/widgets/school_year_picker_chip.dart';
import '../../students/data/students_repository.dart';
import '../../students/models/student.dart';
import '../data/dashboard_repository.dart';
import '../models/dashboard_data.dart';
import '../models/recent_enrollment.dart';
import 'widgets/enrollment_funnel_card.dart';
import 'widgets/my_students_card.dart';
import 'widgets/needs_attention_card.dart';
import 'widgets/pending_enrollment_card.dart';
import 'widgets/recent_enrollments_card.dart';
import 'widgets/recent_students_card.dart';
import 'widgets/section_attendance_card.dart';
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

  /// The school year [_dataFuture] was last fetched with — [build] compares
  /// this against the live [SchoolYearProvider] value on every rebuild (via
  /// `context.watch`) and refetches on a mismatch, same guarded-refetch
  /// idiom as `_TeacherBodyState._loadForSections`'s `identical()` check.
  /// `context.watch` (rather than a manually attached `addListener`) is used
  /// so a picker change is guaranteed to trigger a rebuild — Provider
  /// already handles the listener lifecycle correctly.
  String? _fetchedForYear;

  @override
  void initState() {
    super.initState();
    _dataFuture = _fetch();
  }

  Future<DashboardData> _fetch() {
    final schoolYear = context.read<SchoolYearProvider>().schoolYear;
    _fetchedForYear = schoolYear;
    return widget.repository.fetch(
      role: context.read<AuthProvider>().user?.role,
      schoolYear: schoolYear,
    );
  }

  Future<void> _refresh() async {
    final data = await _fetch();
    if (!mounted) return;
    setState(() => _dataFuture = Future.value(data));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final schoolYear = context.watch<SchoolYearProvider>().schoolYear;
    final today = DateTime.now();

    if (schoolYear != _fetchedForYear) {
      _dataFuture = _fetch();
    }

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
          const Center(child: SchoolYearPickerChip()),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(19),
                onTap: () => widget.onNavigateToTab(ShellTab.more),
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
          // `_AccountingBody` doesn't render `data.totalStudents`/`attendance`
          // (the fields `statsAreLive`/`attendanceIsLive` describe) — it only
          // reads `data.unpaidInvoices` (covered by `showsUnpaidInvoices`
          // below) plus its own separately-fetched financial summary, so a
          // stats/attendance fetch failure isn't real staleness for this
          // role. Every other role's body reads `data.totalStudents`/
          // `attendance` directly.
          final showsLiveData = role != roleAccounting;
          // Only bodies with billing access display the unpaid invoice
          // count — teacher/registrar have no billing access at all
          // (backend's BILLING_ROLES excludes them) and never render this
          // figure, so a failed invoice fetch for them isn't real staleness.
          final showsUnpaidInvoices =
              role != roleTeacher && role != roleRegistrar;
          // Scholarships Awarded: staffAdmin/registrar/accounting all render
          // it now (see DashboardRepository's fetch gating) — only teacher
          // doesn't.
          final showsScholarshipCount = role != roleTeacher;
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
        return _AccountingBody(data: data);
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

class _TeacherBody extends StatefulWidget {
  const _TeacherBody({
    required this.data,
    required this.onOpenAttendance,
    required this.onOpenGrades,
  });

  final DashboardData data;
  final VoidCallback onOpenAttendance;
  final VoidCallback onOpenGrades;

  @override
  State<_TeacherBody> createState() => _TeacherBodyState();
}

class _TeacherBodyState extends State<_TeacherBody> {
  final _today = DateTime.now();

  List<SectionAdvisory>? _sectionsForFetch;
  Map<int, AttendanceBreakdown?> _sectionAttendance = {};
  Future<List<MyStudentsEntry>>? _myStudentsFuture;

  void _loadForSections(List<SectionAdvisory> sections) {
    if (identical(sections, _sectionsForFetch)) return;
    _sectionsForFetch = sections;
    _sectionAttendance = {for (final s in sections) s.id: null};
    _myStudentsFuture = _fetchMyStudents(sections);

    final attendanceRepository = context.read<AttendanceRepository>();
    for (final section in sections) {
      attendanceRepository
          .fetchSummary(
            _today,
            gradeLevel: section.gradeLevel,
            section: section.section,
          )
          .then((breakdown) {
            if (!mounted) return;
            setState(() => _sectionAttendance[section.id] = breakdown);
          })
          .catchError((_) {
            // Leave as null (shown as a loading spinner briefly, then just
            // stays put) — a single section's fetch failing shouldn't crash
            // the rest of the dashboard body.
          });
    }
  }

  /// Joins the roster of every one of the teacher's sections into one list,
  /// capped for dashboard display. `AttendanceApi.fetchRoster` is already
  /// the correct per-section-scoped `enrollment_status=enrolled` call (see
  /// MyStudentsCard's doc comment for why the admin dashboard's
  /// school-wide `/api/students/` card can't be reused here).
  Future<List<MyStudentsEntry>> _fetchMyStudents(
    List<SectionAdvisory> sections,
  ) async {
    final attendanceRepository = context.read<AttendanceRepository>();
    final rosters = await Future.wait(
      sections.map((s) => attendanceRepository.fetchRoster(s)),
    );
    final entries = <MyStudentsEntry>[];
    for (var i = 0; i < sections.length; i++) {
      for (final student in rosters[i]) {
        entries.add(MyStudentsEntry(student: student, section: sections[i]));
      }
    }
    return entries.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    final advisory = context.watch<AdvisoryProvider>();
    final sections = advisory.advisories;
    if (sections.isNotEmpty) {
      _loadForSections(sections);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sections.isNotEmpty)
          TodaysClassesCard(
            sections: sections,
            onOpenAttendance: widget.onOpenAttendance,
            onOpenGrades: widget.onOpenGrades,
          ),
        const SizedBox(height: AppSpacing.interCardGap),
        StatCard(
          label: 'My Sections',
          value: '${sections.length}',
          icon: Icons.groups_outlined,
          pill: StatPill(
            label: 'S.Y. ${widget.data.schoolYear.replaceFirst('S.Y. ', '')}',
            background: AppColors.neutralPillBg,
            textColor: AppColors.neutralPillText,
          ),
        ),
        if (sections.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.interCardGap),
          SectionAttendanceCard(
            date: _today,
            rows: [
              for (final section in sections)
                SectionAttendanceRow(
                  section: section,
                  breakdown: _sectionAttendance[section.id],
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.interCardGap),
          FutureBuilder<List<MyStudentsEntry>>(
            future: _myStudentsFuture,
            builder: (context, snapshot) {
              return MyStudentsCard(entries: snapshot.data ?? const []);
            },
          ),
        ],
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
/// Invoices/Payments to registrar. Recent Enrollments / Recently Added
/// Students mirror `_SuperAdminBody` — both endpoints are read-open to any
/// authenticated staff role, no admin-only restriction.
class _RegistrarBody extends StatefulWidget {
  const _RegistrarBody({required this.data});

  final DashboardData data;

  @override
  State<_RegistrarBody> createState() => _RegistrarBodyState();
}

class _RegistrarBodyState extends State<_RegistrarBody> {
  late Future<List<RecentEnrollment>> _recentEnrollmentsFuture;
  late Future<List<Student>> _recentStudentsFuture;

  @override
  void initState() {
    super.initState();
    _recentEnrollmentsFuture = context
        .read<EnrollmentRepository>()
        .fetchRecentEnrollments();
    _recentStudentsFuture = context
        .read<StudentsRepository>()
        .fetchRecentStudents();
  }

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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: StatCard(
                label: 'Active Students',
                value: '${widget.data.activeStudents}',
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
        StatCard(
          label: 'Scholarships Awarded',
          value: '${widget.data.scholarshipCount}',
          icon: Icons.emoji_events_outlined,
          pill: StatPill(
            label: widget.data.schoolYear,
            background: AppColors.infoBlueBg,
            textColor: AppColors.infoBlueIcon,
          ),
        ),
        const SizedBox(height: AppSpacing.statGridGap),
        PendingEnrollmentCard(
          value: widget.data.pendingEnrollment,
          byYear: widget.data.pendingEnrollmentByYear,
        ),
        const SizedBox(height: AppSpacing.interCardGap),
        FutureBuilder<List<RecentEnrollment>>(
          future: _recentEnrollmentsFuture,
          builder: (context, snapshot) {
            return RecentEnrollmentsCard(
              enrollments: snapshot.data ?? const [],
            );
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
    _recentEnrollmentsFuture = context
        .read<EnrollmentRepository>()
        .fetchRecentEnrollments();
    _recentStudentsFuture = context
        .read<StudentsRepository>()
        .fetchRecentStudents();
  }

  @override
  Widget build(BuildContext context) {
    final enrollmentRepository = context.read<EnrollmentRepository>();
    final billingRepository = context.read<BillingRepository>();
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
        StatCard(
          label: 'Scholarships Awarded',
          value: '${widget.data.scholarshipCount}',
          icon: Icons.emoji_events_outlined,
          pill: StatPill(
            label: widget.data.schoolYear,
            background: AppColors.infoBlueBg,
            textColor: AppColors.infoBlueIcon,
          ),
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
              icon: Icons.receipt_long_outlined,
              title: 'Unpaid invoices',
              count: widget.data.unpaidInvoices,
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
            return RecentEnrollmentsCard(
              enrollments: snapshot.data ?? const [],
            );
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

/// Mirrors the real ASIA web admin dashboard's "revenue strip" for
/// BILLING_ROLES (`DashboardPage.jsx`: Net Billed / Collected / Outstanding
/// tiles + a Collection Rate readout, all sourced from
/// `GET /api/invoices/financial-summary/`) plus the Unpaid Invoices
/// quick-action already used by `_StaffBody`/`_RegistrarBody`. Previously an
/// empty placeholder Column — accounting had no dashboard content and no
/// route to the billing screens at all, since those only lived inside
/// `_StaffBody`, which accounting never renders.
class _AccountingBody extends StatefulWidget {
  const _AccountingBody({required this.data});

  final DashboardData data;

  @override
  State<_AccountingBody> createState() => _AccountingBodyState();
}

class _AccountingBodyState extends State<_AccountingBody> {
  late Future<FinancialSummary> _financialSummaryFuture;
  String? _fetchedForYear;

  @override
  void initState() {
    super.initState();
    _financialSummaryFuture = _fetchSummary();
  }

  Future<FinancialSummary> _fetchSummary() {
    final schoolYear = context.read<SchoolYearProvider>().schoolYear;
    _fetchedForYear = schoolYear;
    return context.read<BillingRepository>().fetchFinancialSummary(
      schoolYear: schoolYear,
    );
  }

  @override
  Widget build(BuildContext context) {
    final billingRepository = context.read<BillingRepository>();
    final schoolYear = context.watch<SchoolYearProvider>().schoolYear;
    if (schoolYear != _fetchedForYear) {
      _financialSummaryFuture = _fetchSummary();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NeedsAttentionCard(
          items: [
            AttentionItem(
              icon: Icons.receipt_long_outlined,
              title: 'Unpaid invoices',
              count: widget.data.unpaidInvoices,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      UnpaidInvoicesListScreen(repository: billingRepository),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.interCardGap),
        FutureBuilder<FinancialSummary>(
          future: _financialSummaryFuture,
          builder: (context, snapshot) {
            final summary = snapshot.data;
            return _FinancialSummaryCard(
              summary: summary,
              loading: snapshot.connectionState != ConnectionState.done,
              onTapOutstanding: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      UnpaidInvoicesListScreen(repository: billingRepository),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.interCardGap),
        StatCard(
          label: 'Scholarships Awarded',
          value: '${widget.data.scholarshipCount}',
          icon: Icons.emoji_events_outlined,
          pill: StatPill(
            label: widget.data.schoolYear,
            background: AppColors.infoBlueBg,
            textColor: AppColors.infoBlueIcon,
          ),
        ),
      ],
    );
  }
}

/// Net Billed / Collected / Outstanding tiles + a Collection Rate readout —
/// mirrors the real ASIA web admin dashboard's revenue strip
/// (`DashboardPage.jsx`, `financialSummary.{net_billed,total_collected,
/// outstanding}`), all from the same `financial-summary` endpoint already
/// wired via `BillingApi.fetchFinancialSummary`. Guardian-blocked
/// server-side but reachable for every staff role including accounting
/// (`billing/views.py:268` only excludes `guardian`).
class _FinancialSummaryCard extends StatelessWidget {
  const _FinancialSummaryCard({
    required this.summary,
    required this.loading,
    required this.onTapOutstanding,
  });

  final FinancialSummary? summary;
  final bool loading;
  final VoidCallback onTapOutstanding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
        border: Border.all(color: AppColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 4),
            child: Text(
              'Financial Summary',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.headingDark,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: _RevenueTile(
                    label: 'Net Billed',
                    value: summary?.netBilled,
                    loading: loading,
                    icon: Icons.receipt_long_outlined,
                    color: AppColors.infoBlueIcon,
                    background: AppColors.infoBlueBg,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _RevenueTile(
                    label: 'Collected',
                    value: summary?.totalCollected,
                    loading: loading,
                    icon: Icons.payments_outlined,
                    color: AppColors.successText,
                    background: AppColors.successBg,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _RevenueTile(
                    label: 'Outstanding',
                    value: summary?.outstanding,
                    loading: loading,
                    icon: Icons.error_outline,
                    color: AppColors.dangerText,
                    background: AppColors.dangerBg,
                    onTap: onTapOutstanding,
                  ),
                ),
              ],
            ),
          ),
          if (!loading && summary != null)
            Builder(
              builder: (context) {
                final s = summary!;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: AppColors.rowDivider),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Collection Rate',
                        style: GoogleFonts.dmSans(
                          fontSize: 11.5,
                          color: AppColors.textMuted3,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${s.collectedPercent}%',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.headingDark,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _RevenueTile extends StatelessWidget {
  const _RevenueTile({
    required this.label,
    required this.value,
    required this.loading,
    required this.icon,
    required this.color,
    required this.background,
    this.onTap,
  });

  final String label;
  final num? value;
  final bool loading;
  final IconData icon;
  final Color color;
  final Color background;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.dashboardBg,
          borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(AppRadii.iconChipSmall),
              ),
              child: Icon(icon, size: 12, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.dmSans(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                color: AppColors.labelUppercase2,
              ),
            ),
            const SizedBox(height: 4),
            loading
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    formatPeso(value ?? 0),
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.headingDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
          ],
        ),
      ),
    );
  }
}
