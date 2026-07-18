import '../../advisory/models/section_advisory.dart';

/// One roster row for the registrar-facing Grade Overview screen — an
/// enrolled student plus their computed grade stats across every subject
/// and grading period recorded so far. There is no backend endpoint that
/// returns this pre-computed (mirrors ASIA web's `GradesPage.jsx`
/// `OverviewTab`, which builds the same thing client-side): one
/// `/api/enrollments/` call for the roster, then one `/api/grades/` call
/// per student (filtered by enrollment id), averaged/counted here.
class GradeOverviewRow {
  const GradeOverviewRow({
    required this.enrollmentId,
    required this.studentName,
    required this.lrn,
    required this.studentNumber,
    required this.schoolLevel,
    required this.gradeLevel,
    required this.section,
    required this.schoolYear,
    required this.strand,
    required this.average,
    required this.passed,
    required this.failed,
    required this.total,
  });

  final int enrollmentId;
  final String studentName;
  final String lrn;
  final String studentNumber;
  final SchoolLevel schoolLevel;
  final String gradeLevel;
  final String section;
  final String schoolYear;
  final String? strand;
  final double? average;
  final int passed;
  final int failed;
  final int total;

  String get initials {
    final parts = studentName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}
