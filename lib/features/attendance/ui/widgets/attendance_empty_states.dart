import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';

/// Shimmer-less loading placeholder — a flat card sized to roughly match
/// the content it's replacing, shown while section lists/rosters fetch.
class LoadingSkeletonCard extends StatelessWidget {
  const LoadingSkeletonCard({super.key, required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

/// Shown when a fetch fails outright — per the handoff, this must be a
/// retry CTA, never a blank screen.
class NetworkErrorState extends StatelessWidget {
  const NetworkErrorState({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off, size: 28, color: Color(0xFFD8B8B4)),
          const SizedBox(height: 8),
          Text(
            "Couldn't load data",
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted1,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Retry',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown for a teacher with no [SectionAdvisory] row assigned — per the
/// handoff this is intentional, not an error, so it gets a distinct,
/// non-alarming empty state with a contact-admin CTA.
class NoSectionsAssignedState extends StatelessWidget {
  const NoSectionsAssignedState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.school_outlined, size: 28, color: Color(0xFFD8B8B4)),
          const SizedBox(height: 8),
          Text(
            'No sections assigned yet',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            "You'll see your sections here once an advisory is assigned.",
            style: GoogleFonts.dmSans(fontSize: 11.5, color: AppColors.textMuted3),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Contact administrator',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Per-component empty state for Grades when a student has no score
/// entries yet for that component.
class NoScoresEnteredState extends StatelessWidget {
  const NoScoresEnteredState({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        'No scores entered',
        style: GoogleFonts.dmSans(fontSize: 11.5, color: AppColors.textMuted3),
      ),
    );
  }
}
