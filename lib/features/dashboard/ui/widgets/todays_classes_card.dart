import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../advisory/models/section_advisory.dart';

/// Teacher's advisory sections for today, per the design mock. No schedule
/// endpoint exists in the RBAC handoff, so period/time slots are display
/// placeholders — the section list itself and the deep-links into
/// Attendance/Grades are real (sourced from the shared AdvisoryProvider).
class TodaysClassesCard extends StatelessWidget {
  const TodaysClassesCard({
    super.key,
    required this.sections,
    required this.onOpenAttendance,
    required this.onOpenGrades,
  });

  final List<SectionAdvisory> sections;
  final VoidCallback onOpenAttendance;
  final VoidCallback onOpenGrades;

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
              "Today's Classes",
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.headingDark,
              ),
            ),
          ),
          for (var i = 0; i < sections.length; i++)
            _ClassRow(
              section: sections[i],
              showDivider: i != sections.length - 1,
              onOpenAttendance: onOpenAttendance,
              onOpenGrades: onOpenGrades,
              // Alternates the action chip like the design mock, since no
              // schedule endpoint tells us which action a given period is for.
              showGradesAction: i.isOdd,
            ),
        ],
      ),
    );
  }
}

class _ClassRow extends StatelessWidget {
  const _ClassRow({
    required this.section,
    required this.showDivider,
    required this.onOpenAttendance,
    required this.onOpenGrades,
    required this.showGradesAction,
  });

  final SectionAdvisory section;
  final bool showDivider;
  final VoidCallback onOpenAttendance;
  final VoidCallback onOpenGrades;
  final bool showGradesAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: AppColors.rowDivider))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              section.displayName,
              style: GoogleFonts.dmSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.headingDark,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            onTap: showGradesAction ? onOpenGrades : onOpenAttendance,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F0),
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Text(
                showGradesAction ? 'Enter Grades' : 'Take Attendance',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
