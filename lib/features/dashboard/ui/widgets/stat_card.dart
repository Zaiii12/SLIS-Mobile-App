import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';

class StatPill {
  const StatPill({required this.label, required this.background, required this.textColor});

  final String label;
  final Color background;
  final Color textColor;
}

/// A single stat tile from the dashboard's 2-column grid (Total Students,
/// Enrolled S.Y., Pending Enrollment).
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.pill,
    this.pillAlignEnd = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final StatPill pill;
  final bool pillAlignEnd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.statCardPadding),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: AppColors.labelUppercase2,
                  ),
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F0),
                  borderRadius: BorderRadius.circular(AppRadii.iconChipSmall),
                ),
                child: Icon(icon, size: 13, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.headingDark,
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: pillAlignEnd ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: pill.background,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Text(
                pill.label,
                style: GoogleFonts.dmSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: pill.textColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
