/// A recently-created enrollment record for the admin dashboard's "Recent
/// Enrollments" list — any status, not just pending (that's already covered
/// by the separate "Pending enrollment approvals" card). Backed by
/// enrollment-service's `GET /api/enrollments/?ordering=-enrollment_id`
/// (`EnrollmentSerializer`, `enrollments/serializers.py:79`). There is no
/// creation timestamp on the `Enrollment` model — `enrollment_id` (a
/// monotonically increasing BigAutoField) is the only real newest-first
/// proxy available.
class RecentEnrollment {
  const RecentEnrollment({
    required this.enrollmentId,
    required this.studentName,
    required this.gradeLevel,
    required this.schoolLevel,
    required this.section,
    required this.schoolYear,
    required this.enrollmentStatus,
  });

  factory RecentEnrollment.fromJson(Map<String, dynamic> json) {
    return RecentEnrollment(
      enrollmentId: json['enrollment_id'].toString(),
      studentName: json['student_name'] as String? ?? '',
      gradeLevel: json['grade_level'] as String? ?? '',
      schoolLevel: json['school_level'] as String? ?? '',
      section: json['section'] as String? ?? '',
      schoolYear: json['school_year'] as String? ?? '',
      enrollmentStatus: json['enrollment_status'] as String? ?? 'enrolled',
    );
  }

  final String enrollmentId;
  final String studentName;
  final String gradeLevel;
  final String schoolLevel;
  final String section;
  final String schoolYear;
  final String enrollmentStatus;

  String get initials {
    final parts = studentName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty);
    final letters = parts.take(2).map((p) => p[0]).join().toUpperCase();
    return letters.isEmpty ? '?' : letters;
  }
}
