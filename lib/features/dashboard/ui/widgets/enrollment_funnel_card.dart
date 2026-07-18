import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';

class _FunnelStep {
  const _FunnelStep({
    required this.label,
    required this.count,
    required this.color,
    required this.background,
    required this.icon,
  });

  final String label;
  final int count;
  final Color color;
  final Color background;
  final IconData icon;
}

/// Admin/super_admin card mirroring the ASIA web dashboard's "Enrollment
/// Funnel" panel (`DashboardPage.jsx:667-714`): Pending → Enrolled →
/// Completed, each step's bar filled to its share of the 3-step total, plus
/// an enrollment-rate footer (enrolled ÷ total students). All 3 counts and
/// the school year come from the same `DashboardData` already powering the
/// 4-stat row above it — no extra fetch needed here.
class EnrollmentFunnelCard extends StatelessWidget {
  const EnrollmentFunnelCard({
    super.key,
    required this.schoolYear,
    required this.pendingCount,
    required this.enrolledCount,
    required this.completedCount,
    required this.enrollmentRate,
  });

  final String schoolYear;
  final int pendingCount;
  final int enrolledCount;
  final int completedCount;
  final int enrollmentRate;

  @override
  Widget build(BuildContext context) {
    final total = pendingCount + enrolledCount + completedCount;
    final steps = [
      _FunnelStep(
        label: 'Pending',
        count: pendingCount,
        color: AppColors.warningText2,
        background: AppColors.warningBg,
        icon: Icons.schedule,
      ),
      _FunnelStep(
        label: 'Enrolled',
        count: enrolledCount,
        color: AppColors.infoBlueIcon,
        background: AppColors.infoBlueBg,
        icon: Icons.calendar_month_outlined,
      ),
      _FunnelStep(
        label: 'Completed',
        count: completedCount,
        color: AppColors.successText2,
        background: AppColors.successBg2,
        icon: Icons.check_circle_outline,
      ),
    ];

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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 4),
            child: Text(
              'Enrollment Funnel',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.headingDark,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$schoolYear · $total total',
                  style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted3),
                ),
                const SizedBox(height: 10),
                for (var i = 0; i < steps.length; i++) ...[
                  _FunnelStepRow(step: steps[i], total: total),
                  if (i < steps.length - 1)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Center(
                        child: Icon(Icons.expand_more, size: 14, color: Color(0xFFD0B0B0)),
                      ),
                    ),
                ],
                if (total > 0) ...[
                  const SizedBox(height: 4),
                  const Divider(height: 1, color: AppColors.cardBorder),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Enrollment rate',
                          style: GoogleFonts.dmSans(fontSize: 11.5, color: AppColors.textMuted3),
                        ),
                        Text(
                          '$enrollmentRate%',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: enrollmentRate >= 70
                                ? AppColors.successText2
                                : AppColors.warningText2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FunnelStepRow extends StatelessWidget {
  const _FunnelStepRow({required this.step, required this.total});

  final _FunnelStep step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (step.count / total * 100).round() : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: step.background,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(step.icon, size: 13, color: step.color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                step.label,
                style: GoogleFonts.dmSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.headingDark,
                ),
              ),
            ),
            Text(
              '${step.count}',
              style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: step.color),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: LinearProgressIndicator(
            value: pct / 100,
            minHeight: 6,
            backgroundColor: AppColors.cardBorder,
            valueColor: AlwaysStoppedAnimation(step.color.withValues(alpha: 0.85)),
          ),
        ),
      ],
    );
  }
}
