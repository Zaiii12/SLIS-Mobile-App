/// A roster row for the Grades list view. There is no single backend
/// endpoint that returns a section's roster joined with each student's
/// grade — `/api/grades/` (see `grades/serializers.py`'s `GradeSerializer`)
/// returns individual `Grade` records filtered by `enrollment`/`subject`/
/// `grading_period`, with no student name attached at all (its
/// `enrollment_detail` only carries `enrollment_id`/`student_id`/
/// `school_year`/`school_level`/`grade_level`/`section`). So this is built
/// client-side by joining the section roster (from `/api/enrollments/`,
/// same call Attendance uses) with the `Grade` records for the selected
/// subject/period, matched by `enrollmentId`.
///
/// [numericGrade] is null for "Not graded" — a student with no saved
/// `Grade` row yet for this subject/period.
class GradedStudent {
  const GradedStudent({
    required this.enrollmentId,
    required this.studentName,
    required this.numericGrade,
    required this.remarks,
  });

  factory GradedStudent.ungraded({required int enrollmentId, required String studentName}) {
    return GradedStudent(
      enrollmentId: enrollmentId,
      studentName: studentName,
      numericGrade: null,
      remarks: null,
    );
  }

  final int enrollmentId;
  final String studentName;
  final double? numericGrade;
  final String? remarks;

  String get initials {
    final parts = studentName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}

/// An individual saved `Grade` record, from `GET/POST /api/grades/`. Field
/// names confirmed against `grades/serializers.py`: pk is `grade_id`, the
/// numeric result is `numeric_grade` (not `final_grade`), and the nested
/// `enrollment_detail` carries `enrollment_id` (used to join back to the
/// roster) but no student name.
class Grade {
  const Grade({
    required this.id,
    required this.enrollmentId,
    required this.numericGrade,
    required this.remarks,
  });

  factory Grade.fromJson(Map<String, dynamic> json) {
    final enrollmentDetail = json['enrollment_detail'] as Map<String, dynamic>?;
    return Grade(
      id: json['grade_id'] as int,
      enrollmentId: (enrollmentDetail?['enrollment_id'] as int?) ?? json['enrollment'] as int,
      numericGrade: (json['numeric_grade'] as num?)?.toDouble(),
      remarks: json['remarks'] as String?,
    );
  }

  final int id;
  final int enrollmentId;
  final double? numericGrade;
  final String? remarks;
}
