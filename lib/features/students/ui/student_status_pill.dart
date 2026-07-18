import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../models/student.dart';

/// Background/text colors for each of the 5 real student statuses, mirroring
/// ASIA web's `STATUS_META` (active=green, inactive=gray, transferred=orange,
/// graduated=blue, dropped=red).
({Color bg, Color text}) studentStatusColors(StudentStatus status) {
  switch (status) {
    case StudentStatus.active:
      return (bg: AppColors.successBg, text: AppColors.successText);
    case StudentStatus.inactive:
      return (bg: AppColors.neutralPillBg, text: AppColors.neutralPillText);
    case StudentStatus.transferred:
      return (bg: AppColors.warningBg, text: AppColors.warningText);
    case StudentStatus.graduated:
      return (bg: AppColors.infoBlueBg, text: AppColors.infoBlueIcon);
    case StudentStatus.dropped:
      return (bg: AppColors.dangerBg, text: AppColors.dangerText);
  }
}

class StudentStatusPill extends StatelessWidget {
  const StudentStatusPill({super.key, required this.status, this.fontSize = 10.5});

  final StudentStatus status;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colors = studentStatusColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        status.label,
        style: GoogleFonts.dmSans(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: colors.text,
        ),
      ),
    );
  }
}
