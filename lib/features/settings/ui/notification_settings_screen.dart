import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/roles.dart';
import '../../../core/theme/app_theme.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../auth/state/auth_provider.dart';
import '../../billing/data/billing_repository.dart';
import '../../billing/data/enrollment_repository.dart';
import '../../billing/ui/billing_format.dart';
import '../../monitoring/data/audit_log_repository.dart';
import '../data/notification_preferences_store.dart';
import '../models/notification_preferences.dart';

enum _LoadStatus { loading, loaded, error }

enum _NotificationCategory { newEnrollments, pendingStudents, unpaidInvoices, auditActivity, financialSummary, todayAttendance }

/// Which categories a role is even offered, in display order — matches each
/// role's real backend access (see this file's doc comment). Unknown/
/// guardian roles fall back to the empty list rather than guessing.
List<_NotificationCategory> _categoriesForRole(String? role) {
  if (hasAnyRole(role, staffAdmin)) {
    return const [
      _NotificationCategory.newEnrollments,
      _NotificationCategory.pendingStudents,
      _NotificationCategory.unpaidInvoices,
      _NotificationCategory.auditActivity,
    ];
  }
  if (hasAnyRole(role, {roleRegistrar})) {
    return const [_NotificationCategory.newEnrollments, _NotificationCategory.pendingStudents];
  }
  if (hasAnyRole(role, {roleAccounting})) {
    return const [_NotificationCategory.unpaidInvoices, _NotificationCategory.financialSummary];
  }
  if (hasAnyRole(role, {roleTeacher})) {
    return const [_NotificationCategory.pendingStudents, _NotificationCategory.todayAttendance];
  }
  return const [];
}

/// A single item in the notification feed, normalized from whichever real
/// backend record produced it (recent enrollment, pending enrollment,
/// unpaid invoice, or audit log entry) so the list can render one row shape.
class _FeedItem {
  const _FeedItem({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.sortKey,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;

  /// Higher sorts first. Each source has its own notion of "newest" (a
  /// monotonic id vs. a real timestamp) — normalized to an int here so the
  /// combined feed can be sorted once.
  final int sortKey;
}

/// "Notification Settings" — there is no push/notification backend in ASIA
/// (every service was grepped; no model, no endpoint), so this screen does
/// two real things instead of being a dead stub: lets the user toggle which
/// categories they care about (persisted on-device via
/// [NotificationPreferencesStore]), and renders a live feed built from
/// actually-real endpoints already used elsewhere in the app. Which
/// categories are even offered is role-gated, matching each role's real
/// backend access (see `_categoriesForRole`):
/// - admin/super_admin: new enrollments, pending applications, unpaid
///   invoices, audit activity.
/// - registrar: new enrollments, pending applications (both school-wide,
///   same as admin — registrar has unfiltered `/api/enrollments/` access).
/// - accounting: unpaid invoices, financial summary.
/// - teacher: pending applications (backend auto-scopes this to the
///   teacher's own advisory roster via `teacher_student_ids()` — no client
///   filtering needed) and today's attendance for their own section(s).
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final _store = NotificationPreferencesStore();

  NotificationPreferences _prefs = const NotificationPreferences();
  bool _prefsLoaded = false;

  _LoadStatus _feedStatus = _LoadStatus.loading;
  List<_FeedItem> _feed = const [];

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadFeed();
  }

  Future<void> _loadPrefs() async {
    final prefs = await _store.load();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _prefsLoaded = true;
    });
  }

  Future<void> _updatePrefs(NotificationPreferences next) async {
    setState(() => _prefs = next);
    await _store.save(next);
    if (!mounted) return;
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    setState(() => _feedStatus = _LoadStatus.loading);

    final role = context.read<AuthProvider>().user?.role;
    final categories = _categoriesForRole(role);
    final enrollmentRepo = context.read<EnrollmentRepository>();
    final billingRepo = context.read<BillingRepository>();
    final auditRepo = context.read<AuditLogRepository>();
    final attendanceRepo = context.read<AttendanceRepository>();
    final items = <_FeedItem>[];

    try {
      if (categories.contains(_NotificationCategory.newEnrollments) && _prefs.newEnrollments) {
        final recent = await enrollmentRepo.fetchRecentEnrollments(limit: 5);
        for (final e in recent) {
          items.add(
            _FeedItem(
              icon: Icons.person_add_alt_1_outlined,
              iconBg: AppColors.infoBlueBg,
              iconColor: AppColors.infoBlueIcon,
              title: 'New enrollment: ${e.studentName.isEmpty ? 'Unknown student' : e.studentName}',
              subtitle: '${e.gradeLevel} · ${e.section} · ${e.schoolYear}',
              sortKey: int.tryParse(e.enrollmentId) ?? 0,
            ),
          );
        }
      }

      if (categories.contains(_NotificationCategory.pendingStudents) && _prefs.pendingStudents) {
        final pending = await enrollmentRepo.fetchPendingEnrollments();
        for (final p in pending.take(5)) {
          items.add(
            _FeedItem(
              icon: Icons.hourglass_top_outlined,
              iconBg: AppColors.warningBg,
              iconColor: AppColors.warningText2,
              title: 'Pending application: ${p.studentName.isEmpty ? 'Unknown student' : p.studentName}',
              subtitle: '${p.gradeLevel} · ${p.schoolYear}',
              sortKey: int.tryParse(p.enrollmentId) ?? 0,
            ),
          );
        }
      }

      if (categories.contains(_NotificationCategory.unpaidInvoices) && _prefs.unpaidInvoices) {
        final page = await billingRepo.fetchUnpaidInvoices();
        for (final inv in page.invoices.take(5)) {
          final studentName = inv.enrollmentDetail?.studentName ?? '';
          items.add(
            _FeedItem(
              icon: Icons.receipt_long_outlined,
              iconBg: AppColors.dangerBg,
              iconColor: AppColors.dangerText,
              title: 'Unpaid invoice: ${studentName.isEmpty ? 'Unknown student' : studentName}',
              subtitle: 'Balance ${formatPeso(inv.balance)} · Due ${formatInvoiceDate(inv.dueDate)}',
              sortKey: int.tryParse(inv.invoiceId) ?? 0,
            ),
          );
        }
      }

      if (categories.contains(_NotificationCategory.auditActivity) && _prefs.auditActivity) {
        final page = await auditRepo.fetchAuditLogs(page: 1);
        for (final entry in page.entries.take(5)) {
          items.add(
            _FeedItem(
              icon: Icons.history,
              iconBg: AppColors.neutralPillBg,
              iconColor: AppColors.neutralPillText,
              title: entry.action.isEmpty ? 'Audit event' : entry.action,
              subtitle: '${entry.userName} · ${entry.module}',
              sortKey: DateTime.tryParse(entry.occurredAt)?.millisecondsSinceEpoch ?? 0,
            ),
          );
        }
      }

      if (categories.contains(_NotificationCategory.financialSummary) && _prefs.financialSummary) {
        final summary = await billingRepo.fetchFinancialSummary();
        items.add(
          _FeedItem(
            icon: Icons.summarize_outlined,
            iconBg: AppColors.infoPurpleBg,
            iconColor: AppColors.infoPurpleIcon,
            title: 'Outstanding balance: ${formatPeso(summary.outstanding)}',
            subtitle: '${summary.invoiceCount} invoices · Collected ${formatPeso(summary.totalCollected)}',
            sortKey: 0,
          ),
        );
      }

      if (categories.contains(_NotificationCategory.todayAttendance) && _prefs.todayAttendance) {
        final summary = await attendanceRepo.fetchSummary(DateTime.now());
        items.add(
          _FeedItem(
            icon: Icons.event_available_outlined,
            iconBg: AppColors.successBg,
            iconColor: AppColors.successText,
            title: "Today's attendance: ${summary.ratePercent}% present",
            subtitle: '${summary.present} present · ${summary.late} late · ${summary.absent} absent',
            sortKey: 0,
          ),
        );
      }

      if (!mounted) return;
      items.sort((a, b) => b.sortKey.compareTo(a.sortKey));
      setState(() {
        _feed = items;
        _feedStatus = _LoadStatus.loaded;
      });
    } catch (error, stackTrace) {
      if (!mounted) return;
      debugPrint('NotificationSettingsScreen._loadFeed failed: $error\n$stackTrace');
      setState(() => _feedStatus = _LoadStatus.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().user?.role;
    final categories = _categoriesForRole(role);

    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      appBar: AppBar(
        title: Text(
          'Notification Settings',
          style: GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.headingDark),
        ),
      ),
      body: !_prefsLoaded
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadFeed,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.dashboardScreenPadding),
                children: [
                  _SectionLabel('Alert categories'),
                  const SizedBox(height: 8),
                  _TogglesCard(
                    categories: categories,
                    prefs: _prefs,
                    onChanged: _updatePrefs,
                  ),
                  const SizedBox(height: AppSpacing.interCardGap),
                  _SectionLabel('Recent activity'),
                  const SizedBox(height: 8),
                  _FeedCard(status: _feedStatus, items: _feed, onRetry: _loadFeed),
                ],
              ),
            ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: AppColors.labelUppercase2,
      ),
    );
  }
}

class _ToggleSpec {
  const _ToggleSpec({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
}

class _TogglesCard extends StatelessWidget {
  const _TogglesCard({required this.categories, required this.prefs, required this.onChanged});

  final List<_NotificationCategory> categories;
  final NotificationPreferences prefs;
  final ValueChanged<NotificationPreferences> onChanged;

  @override
  Widget build(BuildContext context) {
    final specs = {
      _NotificationCategory.newEnrollments: _ToggleSpec(
        icon: Icons.person_add_alt_1_outlined,
        label: 'New enrollments',
        subtitle: 'Notify when a student is newly enrolled',
        value: prefs.newEnrollments,
        onChanged: (v) => onChanged(prefs.copyWith(newEnrollments: v)),
      ),
      _NotificationCategory.pendingStudents: _ToggleSpec(
        icon: Icons.hourglass_top_outlined,
        label: 'Pending applications',
        subtitle: 'Notify when a student enrollment is awaiting approval',
        value: prefs.pendingStudents,
        onChanged: (v) => onChanged(prefs.copyWith(pendingStudents: v)),
      ),
      _NotificationCategory.unpaidInvoices: _ToggleSpec(
        icon: Icons.receipt_long_outlined,
        label: 'Unpaid invoices',
        subtitle: 'Notify when a new unpaid invoice comes in',
        value: prefs.unpaidInvoices,
        onChanged: (v) => onChanged(prefs.copyWith(unpaidInvoices: v)),
      ),
      _NotificationCategory.auditActivity: _ToggleSpec(
        icon: Icons.history,
        label: 'Audit activity',
        subtitle: 'Notify on system audit log events',
        value: prefs.auditActivity,
        onChanged: (v) => onChanged(prefs.copyWith(auditActivity: v)),
      ),
      _NotificationCategory.financialSummary: _ToggleSpec(
        icon: Icons.summarize_outlined,
        label: 'Financial summary',
        subtitle: 'Notify on billed, collected, and outstanding balance changes',
        value: prefs.financialSummary,
        onChanged: (v) => onChanged(prefs.copyWith(financialSummary: v)),
      ),
      _NotificationCategory.todayAttendance: _ToggleSpec(
        icon: Icons.event_available_outlined,
        label: "Today's attendance",
        subtitle: 'Notify on your section\'s daily attendance summary',
        value: prefs.todayAttendance,
        onChanged: (v) => onChanged(prefs.copyWith(todayAttendance: v)),
      ),
    };

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
        border: Border.all(color: AppColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < categories.length; i++)
            _ToggleRow(
              icon: specs[categories[i]]!.icon,
              label: specs[categories[i]]!.label,
              subtitle: specs[categories[i]]!.subtitle,
              value: specs[categories[i]]!.value,
              onChanged: specs[categories[i]]!.onChanged,
              showDivider: i < categories.length - 1,
            ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.showDivider,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: showDivider ? const Border(bottom: BorderSide(color: AppColors.rowDivider)) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0F0),
              borderRadius: BorderRadius.circular(AppRadii.iconChipLarge),
            ),
            child: Icon(icon, size: 14, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.headingDark),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted3),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.status, required this.items, required this.onRetry});

  final _LoadStatus status;
  final List<_FeedItem> items;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
        border: Border.all(color: AppColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (status) {
      case _LoadStatus.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      case _LoadStatus.error:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            children: [
              Text(
                "Couldn't load recent activity",
                style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textMuted1),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: onRetry,
                child: Text('Retry', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: AppColors.primary)),
              ),
            ],
          ),
        );
      case _LoadStatus.loaded:
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Center(
              child: Text(
                'No recent activity to show',
                style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.textMuted3),
              ),
            ),
          );
        }
        return Column(
          children: [
            for (var i = 0; i < items.length; i++) _FeedRow(item: items[i], showDivider: i < items.length - 1),
          ],
        );
    }
  }
}

class _FeedRow extends StatelessWidget {
  const _FeedRow({required this.item, required this.showDivider});

  final _FeedItem item;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: showDivider ? const Border(bottom: BorderSide(color: AppColors.rowDivider)) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: item.iconBg,
              borderRadius: BorderRadius.circular(AppRadii.iconChipLarge),
            ),
            child: Icon(item.icon, size: 13, color: item.iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.headingDark),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted3),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
