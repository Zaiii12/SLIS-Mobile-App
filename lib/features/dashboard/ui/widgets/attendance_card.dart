import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../models/dashboard_data.dart';

class AttendanceCard extends StatelessWidget {
  const AttendanceCard({super.key, required this.attendance, required this.date});

  final AttendanceBreakdown attendance;
  final DateTime date;

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
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Today's Attendance",
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.headingDark,
                  ),
                ),
                Text(
                  DateFormat('MMMM d').format(date),
                  style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted3),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              children: [
                Row(
                  children: [
                    _MiniStat(
                      value: attendance.present,
                      label: 'Present',
                      background: AppColors.successBg2,
                      textColor: AppColors.successText2,
                    ),
                    const SizedBox(width: 8),
                    _MiniStat(
                      value: attendance.late,
                      label: 'Late',
                      background: AppColors.warningBg,
                      textColor: AppColors.warningText,
                      labelColor: AppColors.warningText2,
                    ),
                    const SizedBox(width: 8),
                    _MiniStat(
                      value: attendance.absent,
                      label: 'Absent',
                      background: AppColors.dangerBg2,
                      textColor: AppColors.dangerText,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Attendance rate',
                      style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted3),
                    ),
                    Text(
                      '${attendance.ratePercent}%',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.successText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  child: LinearProgressIndicator(
                    value: attendance.ratePercent / 100,
                    minHeight: 6,
                    backgroundColor: AppColors.cardBorder,
                    valueColor: const AlwaysStoppedAnimation(AppColors.successFill),
                  ),
                ),
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
    Color? labelColor,
  }) : labelColor = labelColor ?? textColor;

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
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.dmSans(fontSize: 10, color: labelColor),
            ),
          ],
        ),
      ),
    );
  }
}
