import 'package:shared_preferences/shared_preferences.dart';

import '../models/notification_preferences.dart';

/// Persists [NotificationPreferences] to on-device storage via
/// `shared_preferences`. Purely local — there is no server-side notification
/// preferences endpoint to sync against.
class NotificationPreferencesStore {
  static const _newEnrollmentsKey = 'notif_pref_new_enrollments';
  static const _pendingStudentsKey = 'notif_pref_pending_students';
  static const _unpaidInvoicesKey = 'notif_pref_unpaid_invoices';
  static const _auditActivityKey = 'notif_pref_audit_activity';
  static const _financialSummaryKey = 'notif_pref_financial_summary';
  static const _todayAttendanceKey = 'notif_pref_today_attendance';

  Future<NotificationPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return NotificationPreferences(
      newEnrollments: prefs.getBool(_newEnrollmentsKey) ?? true,
      pendingStudents: prefs.getBool(_pendingStudentsKey) ?? true,
      unpaidInvoices: prefs.getBool(_unpaidInvoicesKey) ?? true,
      auditActivity: prefs.getBool(_auditActivityKey) ?? true,
      financialSummary: prefs.getBool(_financialSummaryKey) ?? true,
      todayAttendance: prefs.getBool(_todayAttendanceKey) ?? true,
    );
  }

  Future<void> save(NotificationPreferences preferences) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_newEnrollmentsKey, preferences.newEnrollments);
    await prefs.setBool(_pendingStudentsKey, preferences.pendingStudents);
    await prefs.setBool(_unpaidInvoicesKey, preferences.unpaidInvoices);
    await prefs.setBool(_auditActivityKey, preferences.auditActivity);
    await prefs.setBool(_financialSummaryKey, preferences.financialSummary);
    await prefs.setBool(_todayAttendanceKey, preferences.todayAttendance);
  }
}
