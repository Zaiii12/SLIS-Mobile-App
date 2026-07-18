import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/roles.dart';
import '../../../core/theme/app_theme.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../auth/state/auth_provider.dart';
import '../../auth/ui/login_screen.dart';
import '../../monitoring/data/audit_log_repository.dart';
import '../../monitoring/ui/audit_log_screen.dart';
import '../../narrative/data/narrative_repository.dart';
import '../../narrative/ui/narrative_screen.dart';
import '../../settings/ui/change_password_screen.dart';
import '../../settings/ui/help_support_screen.dart';
import '../../settings/ui/notification_settings_screen.dart';
import '../../staff/data/staff_repository.dart';
import '../../staff/ui/staff_directory_screen.dart';

const _roleLabels = {
  roleTeacher: 'Teacher',
  roleRegistrar: 'Registrar',
  roleAdmin: 'Admin',
  roleSuperAdmin: 'Super Admin',
  roleAccounting: 'Accounting',
  roleGuardian: 'Guardian',
};

/// The "More" tab: profile summary, settings, audit log (admin/super_admin
/// only), narrative reports (teacher only), app info, and log out.
/// Notification Settings and Help & Support push their own screens (see
/// `../../settings/ui/`) — there's no backend notification/support system
/// in ASIA, so those screens combine local device prefs and static content
/// with real data pulled from endpoints already used elsewhere in the app.
/// Audit Log used to be its own bottom-nav tab, `staffAdmin`-only; it now
/// lives here as a row instead, freeing that nav slot for Calendar (shown to
/// every role). Still gated to `staffAdmin` — `GET /api/auth/audit-logs/`
/// is `ADMIN_ROLES`-only server-side, so nobody else can use it anyway.
/// Narrative Reports is `teacher`-only for the same "don't crowd the bottom
/// nav" reason (teacher already has Dashboard/Students/Attendance/Grades/
/// Calendar/More) — `NarrativeReportViewSet` is `IsAdvisoryTeacherOrStaff`,
/// so only teacher/admin/super_admin/registrar could write/read it anyway,
/// and this app only offers teacher-authored entry (admin/registrar
/// oversight of narrative reports isn't built — same scope boundary as
/// Attendance/Grades, which staff also can't enter from mobile).
/// Change Password is available to every role — self-service via
/// `PATCH /api/auth/users/{id}/` with the caller's own id.
class MoreScreen extends StatelessWidget {
  const MoreScreen({
    super.key,
    required this.auditLogRepository,
    required this.narrativeRepository,
    required this.attendanceRepository,
    required this.staffRepository,
  });

  final AuditLogRepository auditLogRepository;
  final NarrativeRepository narrativeRepository;
  final AttendanceRepository attendanceRepository;
  final StaffRepository staffRepository;

  Future<void> _logout(BuildContext context) async {
    await context.read<AuthProvider>().logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final roleLabel = _roleLabels[user?.role] ?? user?.role ?? '';
    final showAuditLog = hasAnyRole(user?.role, staffAdmin);
    final showNarrative = user?.role == roleTeacher;

    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'More',
          style: GoogleFonts.dmSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.headingDark,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.dashboardScreenPadding),
        children: [
          _ProfileCard(name: user?.name ?? '', initials: user?.initials ?? '?', roleLabel: roleLabel),
          const SizedBox(height: AppSpacing.interCardGap),
          _SettingsCard(
            showAuditLog: showAuditLog,
            showNarrative: showNarrative,
            showStaffDirectory: showAuditLog,
            onAuditLogTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AuditLogScreen(repository: auditLogRepository),
              ),
            ),
            onNarrativeTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => NarrativeScreen(
                  narrativeRepository: narrativeRepository,
                  attendanceRepository: attendanceRepository,
                ),
              ),
            ),
            onChangePasswordTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
            ),
            onStaffDirectoryTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => StaffDirectoryScreen(repository: staffRepository),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.interCardGap),
          const _AppInfoCard(),
          const SizedBox(height: AppSpacing.interCardGap),
          _LogoutRow(onTap: () => _logout(context)),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.name, required this.initials, required this.roleLabel});

  final String name;
  final String initials;
  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
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
                initials,
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.dmSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.headingDark,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '$roleLabel · South Lakes Integrated School',
                  style: GoogleFonts.dmSans(fontSize: 11.5, color: AppColors.textMuted3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.showAuditLog,
    required this.showNarrative,
    required this.showStaffDirectory,
    required this.onAuditLogTap,
    required this.onNarrativeTap,
    required this.onChangePasswordTap,
    required this.onStaffDirectoryTap,
  });

  final bool showAuditLog;
  final bool showNarrative;
  final bool showStaffDirectory;
  final VoidCallback onAuditLogTap;
  final VoidCallback onNarrativeTap;
  final VoidCallback onChangePasswordTap;
  final VoidCallback onStaffDirectoryTap;

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
        children: [
          _SettingsRow(
            icon: Icons.lock_outline,
            label: 'Change Password',
            showDivider: true,
            onTap: onChangePasswordTap,
          ),
          _SettingsRow(
            icon: Icons.notifications_outlined,
            label: 'Notification Settings',
            showDivider: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
            ),
          ),
          _SettingsRow(
            icon: Icons.help_outline,
            label: 'Help & Support',
            showDivider: showStaffDirectory || showAuditLog || showNarrative,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
            ),
          ),
          if (showStaffDirectory)
            _SettingsRow(
              icon: Icons.badge_outlined,
              label: 'Staff Directory',
              showDivider: showAuditLog || showNarrative,
              onTap: onStaffDirectoryTap,
            ),
          if (showNarrative)
            _SettingsRow(
              icon: Icons.edit_note_outlined,
              label: 'Narrative Reports',
              showDivider: showAuditLog,
              onTap: onNarrativeTap,
            ),
          if (showAuditLog)
            _SettingsRow(
              icon: Icons.history,
              label: 'Audit Log',
              showDivider: false,
              onTap: onAuditLogTap,
            ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.showDivider,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(bottom: BorderSide(color: AppColors.rowDivider))
              : null,
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
              child: Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.headingDark,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 13, color: Color(0xFFD0B0B0)),
          ],
        ),
      ),
    );
  }
}

class _AppInfoCard extends StatelessWidget {
  const _AppInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.neutralPillBg,
                borderRadius: BorderRadius.circular(AppRadii.iconChipLarge),
              ),
              child: const Icon(Icons.info_outline, size: 14, color: AppColors.neutralPillText),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'App Info',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.headingDark,
                ),
              ),
            ),
            Text('v1.0.0', style: GoogleFonts.dmSans(fontSize: 11.5, color: AppColors.textMuted3)),
          ],
        ),
      ),
    );
  }
}

class _LogoutRow extends StatelessWidget {
  const _LogoutRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
          border: Border.all(color: AppColors.loginCardBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout, size: 15, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'Log Out',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
