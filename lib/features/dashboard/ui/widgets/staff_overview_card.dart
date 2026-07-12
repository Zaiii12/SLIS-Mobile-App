import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';

/// Super_admin-only card. No staffing endpoint exists per the handoff —
/// values are placeholders until a real one ships.
class StaffOverviewCard extends StatelessWidget {
  const StaffOverviewCard({
    super.key,
    this.teacherCount = 0,
    this.onLeaveCount = 0,
    this.noAdviserCount = 0,
  });

  final int teacherCount;
  final int onLeaveCount;
  final int noAdviserCount;

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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.cardBorder))),
            child: Text(
              'Staff Overview',
              style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.headingDark),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                _MiniStat(value: teacherCount, label: 'Teachers', background: AppColors.neutralPillBg, textColor: AppColors.headingDark, labelColor: AppColors.neutralPillText),
                const SizedBox(width: 8),
                _MiniStat(value: onLeaveCount, label: 'On Leave', background: AppColors.warningBg, textColor: AppColors.warningText, labelColor: AppColors.warningText2),
                const SizedBox(width: 8),
                _MiniStat(value: noAdviserCount, label: 'No Adviser', background: AppColors.dangerBg2, textColor: AppColors.dangerText, labelColor: AppColors.dangerText),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.value,
    required this.label,
    required this.background,
    required this.textColor,
    required this.labelColor,
  });

  final int value;
  final String label;
  final Color background;
  final Color textColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            Text('$value', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
            Text(label, style: GoogleFonts.dmSans(fontSize: 10, color: labelColor)),
          ],
        ),
      ),
    );
  }
}
