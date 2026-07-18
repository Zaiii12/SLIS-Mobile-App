/// On-device toggle state for the "Notification Settings" screen. There is
/// no push-notification or preferences backend in ASIA (confirmed by
/// grepping every service) — these flags are stored locally only and gate
/// which categories appear in this screen's live activity feed, which is
/// itself built from real data rather than fabricated alerts. Not every
/// field is shown to every role — [NotificationSettingsScreen] only renders
/// (and only fetches for) the categories relevant to the signed-in role's
/// real backend access, mirroring `DashboardRepository`'s per-role gating.
/// Defaults are all-on so a fresh install behaves like notifications "just
/// work".
class NotificationPreferences {
  const NotificationPreferences({
    this.newEnrollments = true,
    this.pendingStudents = true,
    this.unpaidInvoices = true,
    this.auditActivity = true,
    this.financialSummary = true,
    this.todayAttendance = true,
  });

  /// Admin/super_admin/registrar: newest enrollment records school-wide.
  final bool newEnrollments;

  /// Admin/super_admin/registrar/teacher: pending enrollment applications
  /// (school-wide for the first three, own-roster-scoped for teacher — the
  /// backend applies the narrower filter automatically).
  final bool pendingStudents;

  /// Admin/super_admin/accounting: unpaid invoices.
  final bool unpaidInvoices;

  /// Admin/super_admin only: audit log activity.
  final bool auditActivity;

  /// Accounting (also admin/super_admin): billed/collected/outstanding snapshot.
  final bool financialSummary;

  /// Teacher: today's attendance breakdown for their own advisory section(s).
  final bool todayAttendance;

  NotificationPreferences copyWith({
    bool? newEnrollments,
    bool? pendingStudents,
    bool? unpaidInvoices,
    bool? auditActivity,
    bool? financialSummary,
    bool? todayAttendance,
  }) {
    return NotificationPreferences(
      newEnrollments: newEnrollments ?? this.newEnrollments,
      pendingStudents: pendingStudents ?? this.pendingStudents,
      unpaidInvoices: unpaidInvoices ?? this.unpaidInvoices,
      auditActivity: auditActivity ?? this.auditActivity,
      financialSummary: financialSummary ?? this.financialSummary,
      todayAttendance: todayAttendance ?? this.todayAttendance,
    );
  }
}
