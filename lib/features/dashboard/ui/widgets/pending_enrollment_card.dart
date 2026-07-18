import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';

/// The "Pending Enrollment" stat card, which spans both grid columns and
/// uses a horizontal layout (icon+label+value left, "needs action" pill
/// right) unlike the stacked layout of [StatCard].
///
/// [value] is now a true all-years total (previously scoped to only the
/// current school year, which silently hid stragglers from other years —
/// see DashboardApi._fetchPendingEnrollmentByYear). [byYear] renders a
/// small breakdown line underneath so a mixed-year total isn't just a bare
/// number with no context.
class PendingEnrollmentCard extends StatelessWidget {
  const PendingEnrollmentCard({
    super.key,
    required this.value,
    this.byYear = const {},
  });

  final int value;
  final Map<String, int> byYear;

  @override
  Widget build(BuildContext context) {
    final years = byYear.keys.toList()..sort((a, b) => b.compareTo(a));

    return Container(
      padding: const EdgeInsets.all(AppSpacing.statCardPadding),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0F0),
                        borderRadius: BorderRadius.circular(
                          AppRadii.iconChipSmall,
                        ),
                      ),
                      child: const Icon(
                        Icons.assignment_outlined,
                        size: 13,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'PENDING ENROLLMENT',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                        color: AppColors.labelUppercase2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '$value',
                  style: GoogleFonts.dmSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.headingDark,
                  ),
                ),
                if (years.length > 1) ...[
                  const SizedBox(height: 4),
                  Text(
                    years.map((y) => 'S.Y. $y: ${byYear[y]}').join('  ·  '),
                    style: GoogleFonts.dmSans(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted2,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.dangerBg,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Text(
              'needs action',
              style: GoogleFonts.dmSans(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: AppColors.dangerText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
