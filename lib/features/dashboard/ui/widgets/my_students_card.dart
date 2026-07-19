import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../advisory/models/section_advisory.dart';
import '../../../attendance/models/roster_entry.dart';
import '../../../students/data/students_repository.dart';
import '../../../students/ui/student_detail_screen.dart';

/// Teacher dashboard: a few students from the teacher's own advisory
/// sections, backed by `GET /api/enrollments/?school_year=&school_level=&
/// grade_level=&section=&enrollment_status=enrolled`
/// (`AttendanceApi.fetchRoster`, reused here since it's already the correct
/// per-section-scoped enrolled-roster call — the admin dashboard's
/// `RecentStudentsCard`/`fetchRecentStudents` hits the unscoped
/// `/api/students/` list and can't be reused for a teacher without leaking
/// the whole school's students).
class MyStudentsCard extends StatelessWidget {
  const MyStudentsCard({super.key, required this.entries});

  final List<MyStudentsEntry> entries;

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
              'My Students',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.headingDark,
              ),
            ),
          ),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Text(
                'No students in your sections yet',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppColors.textMuted3,
                ),
              ),
            )
          else
            for (final entry in entries) _StudentRow(entry: entry),
        ],
      ),
    );
  }
}

class MyStudentsEntry {
  const MyStudentsEntry({required this.student, required this.section});

  final RosterEntry student;
  final SectionAdvisory section;
}

class _StudentRow extends StatefulWidget {
  const _StudentRow({required this.entry});

  final MyStudentsEntry entry;

  @override
  State<_StudentRow> createState() => _StudentRowState();
}

class _StudentRowState extends State<_StudentRow> {
  bool _loading = false;

  Future<void> _openProfile() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final student = await context.read<StudentsRepository>().fetchStudentById(
        widget.entry.student.studentId,
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
    final entry = widget.entry;
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
                  entry.student.initials,
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
              child: Text(
                entry.student.studentName.isEmpty
                    ? 'Unknown student'
                    : entry.student.studentName,
                style: GoogleFonts.dmSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.headingDark,
                ),
                overflow: TextOverflow.ellipsis,
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
                  color: AppColors.neutralPillBg,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  entry.section.displayName,
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neutralPillText,
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
