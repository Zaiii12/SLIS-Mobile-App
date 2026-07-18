import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../advisory/models/section_advisory.dart';
import '../../models/dashboard_data.dart';

/// Teacher dashboard: today's attendance rate broken down per advisory
/// section, backed by `GET /api/attendance/summary/?grade_level=&section=`
/// (`AttendanceApi.fetchSummary`) — one call per section since the endpoint
/// has no group-by-section aggregate. A teacher with more than one advisory
/// gets a per-section figure instead of one blended number, which is what
/// the old single "Week Attendance Avg" stat tile hid.
class SectionAttendanceCard extends StatelessWidget {
  const SectionAttendanceCard({
    super.key,
    required this.rows,
    required this.date,
  });

  final List<SectionAttendanceRow> rows;
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
            child: Text(
              "Today's Attendance by Section",
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.headingDark,
              ),
            ),
          ),
          for (var i = 0; i < rows.length; i++)
            _SectionRow(row: rows[i], showDivider: i != rows.length - 1),
        ],
      ),
    );
  }
}

class SectionAttendanceRow {
  const SectionAttendanceRow({required this.section, required this.breakdown});

  final SectionAdvisory section;
  final AttendanceBreakdown? breakdown;
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({required this.row, required this.showDivider});

  final SectionAttendanceRow row;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final breakdown = row.breakdown;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: AppColors.rowDivider))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              row.section.displayName,
              style: GoogleFonts.dmSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.headingDark,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (breakdown == null)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (breakdown.total == 0)
            Text(
              'No records',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: AppColors.textMuted3,
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.successBg,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Text(
                '${breakdown.ratePercent}% present',
                style: GoogleFonts.dmSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.successText,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
