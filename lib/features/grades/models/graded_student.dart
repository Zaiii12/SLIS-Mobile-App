/// A roster row for the Grades list view, from
/// `GET /api/grades/?section_advisory=<id>&subject=<id>&period=<period>`.
/// [finalGrade] is null for "Not graded" — a student with no saved grade
/// yet for this subject/period.
class GradedStudent {
  const GradedStudent({
    required this.enrollmentId,
    required this.studentName,
    required this.finalGrade,
    required this.remarks,
  });

  factory GradedStudent.fromJson(Map<String, dynamic> json) {
    final student = json['student'];
    final name = student is Map<String, dynamic>
        ? student['name'] as String? ?? ''
        : json['student_name'] as String? ?? '';
    return GradedStudent(
      enrollmentId: json['enrollment'] as int,
      studentName: name,
      finalGrade: (json['final_grade'] as num?)?.toDouble(),
      remarks: json['remarks'] as String?,
    );
  }

  final int enrollmentId;
  final String studentName;
  final double? finalGrade;
  final String? remarks;

  String get initials {
    final parts = studentName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}
