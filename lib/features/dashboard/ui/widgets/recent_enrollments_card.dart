import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../students/data/students_repository.dart';
import '../../../students/ui/student_detail_screen.dart';
import '../../models/recent_enrollment.dart';

const _statusLabels = {
  'enrolled': 'Enrolled',
  'pending': 'Pending',
  'cancelled': 'Cancelled',
  'completed': 'Completed',
  'transferred_out': 'Transferred Out',
};

const _statusColors = {
  'enrolled': (AppColors.successBg, AppColors.successText),
  'pending': (AppColors.warningBg, AppColors.warningText2),
  'cancelled': (AppColors.dangerBg, AppColors.dangerText),
  'completed': (AppColors.neutralPillBg, AppColors.neutralPillText),
  'transferred_out': (AppColors.neutralPillBg, AppColors.neutralPillText),
};

/// Admin/super_admin card: newest enrollment records (any status), backed by
/// real `GET /api/enrollments/?ordering=-enrollment_id`
/// (`EnrollmentRepository.fetchRecentEnrollments`). Distinct from the
/// existing "Pending enrollment approvals" NeedsAttentionCard item, which
/// only counts `enrollment_status=pending` rows.
class RecentEnrollmentsCard extends StatelessWidget {
  const RecentEnrollmentsCard({super.key, required this.enrollments});

  final List<RecentEnrollment> enrollments;

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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 4),
            child: Text(
              'Recent Enrollments',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.headingDark,
              ),
            ),
          ),
          if (enrollments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Text(
                'No enrollment records yet',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppColors.textMuted3,
                ),
              ),
            )
          else
            for (final enrollment in enrollments)
              _EnrollmentRow(enrollment: enrollment),
        ],
      ),
    );
  }
}

class _EnrollmentRow extends StatefulWidget {
  const _EnrollmentRow({required this.enrollment});

  final RecentEnrollment enrollment;

  @override
  State<_EnrollmentRow> createState() => _EnrollmentRowState();
}

class _EnrollmentRowState extends State<_EnrollmentRow> {
  bool _loading = false;

  Future<void> _openProfile() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final student = await context.read<StudentsRepository>().fetchStudentById(
        widget.enrollment.studentId,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => StudentDetailScreen(student: student)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open student profile.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enrollment = widget.enrollment;
    final colors =
        _statusColors[enrollment.enrollmentStatus] ??
        (AppColors.neutralPillBg, AppColors.neutralPillText);
    final label =
        _statusLabels[enrollment.enrollmentStatus] ??
        enrollment.enrollmentStatus;

    return InkWell(
      onTap: _openProfile,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.rowDivider)),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFDF3F2),
              ),
              child: Center(
                child: Text(
                  enrollment.initials,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    enrollment.studentName.isEmpty
                        ? 'Unknown student'
                        : enrollment.studentName,
                    style: GoogleFonts.dmSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.headingDark,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${enrollment.gradeLevel} · ${enrollment.section} · ${enrollment.schoolYear}',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppColors.textMuted3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (_loading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.$1,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: colors.$2,
                  ),
                ),
              ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted3),
          ],
        ),
      ),
    );
  }
}
