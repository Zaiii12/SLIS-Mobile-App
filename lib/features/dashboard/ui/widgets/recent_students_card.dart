import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../students/models/student.dart';

/// Admin/super_admin card: newest student records, backed by real
/// `GET /api/students/?ordering=-student_id`
/// (`StudentsRepository.fetchRecentStudents`). `student_id` (auto-
/// incrementing PK) is the only genuine newest-first proxy — the model has
/// no `created_at` field.
class RecentStudentsCard extends StatelessWidget {
  const RecentStudentsCard({super.key, required this.students});

  final List<Student> students;

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
              'Recently Added Students',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.headingDark,
              ),
            ),
          ),
          if (students.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Text(
                'No student records yet',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppColors.textMuted3,
                ),
              ),
            )
          else
            for (final student in students) _StudentRow(student: student),
        ],
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                student.initials,
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
                  student.name.isEmpty ? 'Unknown student' : student.name,
                  style: GoogleFonts.dmSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.headingDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  'LRN ${student.lrn}',
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: student.isActive
                  ? AppColors.successBg
                  : AppColors.neutralPillBg,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Text(
              student.status,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: student.isActive
                    ? AppColors.successText
                    : AppColors.neutralPillText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
