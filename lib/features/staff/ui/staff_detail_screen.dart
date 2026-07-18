import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../models/staff_member.dart';

const _roleLabels = {
  'super_admin': 'Super Admin',
  'admin': 'Admin',
  'registrar': 'Registrar',
  'teacher': 'Teacher',
  'accounting': 'Accounting',
  'guardian': 'Guardian',
};

/// Read-only profile view — this app has no account-editing/role-assignment
/// UI by design (see `UserDetailView`'s PATCH/DELETE support server-side,
/// which stays web-only). Deliberately does not reuse
/// `MonitoringSectionsScreen` — that's a teacher's section drill-down, not a
/// generic profile, and most staff here aren't teachers at all.
class StaffDetailScreen extends StatelessWidget {
  const StaffDetailScreen({super.key, required this.member});

  final StaffMember member;

  @override
  Widget build(BuildContext context) {
    final roleLabel = _roleLabels[member.role] ?? member.role;
    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      appBar: AppBar(
        title: Text(
          'Staff Profile',
          style: GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.headingDark),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.dashboardScreenPadding),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
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
                      member.initials,
                      style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  member.name.isEmpty ? 'Unnamed' : member.name,
                  style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.headingDark),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.neutralPillBg,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    roleLabel,
                    style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.neutralPillText),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.interCardGap),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
              border: Border.all(color: AppColors.cardBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: _InfoRow(icon: Icons.email_outlined, label: 'Email', value: member.email),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
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
                Text(label, style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted3)),
                const SizedBox(height: 1),
                Text(
                  value.isEmpty ? '—' : value,
                  style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.headingDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
