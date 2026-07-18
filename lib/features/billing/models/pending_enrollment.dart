/// A pending enrollment application, backed by enrollment-service's real
/// `GET /api/enrollments/?enrollment_status=pending` (confirmed live: 19
/// real records, `EnrollmentSerializer` embeds `student_detail` with LRN,
/// full name, sex, birth_date — enrollments/serializers.py:55-83).
///
/// `applicationType` is NOT a stored field anywhere in ASIA — there is no
/// "application" resource, just an Enrollment row with `enrollment_status`.
/// It's derived client-side (see EnrollmentRepository) from two other real
/// signals: a `PreviousSchool` record on student-service means Transferee;
/// any other (non-pending) enrollment record for the same student means
/// Continuing; neither means New Student. This is a heuristic, not a
/// backend-confirmed classification.
class PendingEnrollment {
  const PendingEnrollment({
    required this.enrollmentId,
    required this.studentId,
    required this.studentName,
    required this.lrn,
    required this.studentNumber,
    required this.sex,
    required this.birthDate,
    required this.gradeLevel,
    required this.schoolLevel,
    required this.schoolYear,
    required this.section,
    required this.applicationType,
    this.previousSchoolName,
    this.previousSchoolAddress,
  });

  factory PendingEnrollment.fromJson(Map<String, dynamic> json) {
    final studentDetail = json['student_detail'] as Map<String, dynamic>?;
    return PendingEnrollment(
      enrollmentId: json['enrollment_id'].toString(),
      studentId: (json['student_id'] ?? json['student']).toString(),
      studentName: json['student_name'] as String? ?? '',
      lrn: studentDetail?['lrn'] as String? ?? '',
      studentNumber: studentDetail?['student_number'] as String?,
      sex: studentDetail?['sex'] as String? ?? '',
      birthDate: studentDetail?['birth_date'] as String? ?? '',
      gradeLevel: json['grade_level'] as String? ?? '',
      schoolLevel: json['school_level'] as String? ?? '',
      schoolYear: json['school_year'] as String? ?? '',
      section: json['section'] as String? ?? '',
      // Filled in by EnrollmentRepository after the initial fetch — the
      // enrollment payload alone doesn't carry this.
      applicationType: 'Unknown',
    );
  }

  final String enrollmentId;
  final String studentId;
  final String studentName;
  final String lrn;
  final String? studentNumber;
  final String sex;
  final String birthDate;
  final String gradeLevel;
  final String schoolLevel;
  final String schoolYear;
  final String section;
  final String applicationType;
  final String? previousSchoolName;
  final String? previousSchoolAddress;

  PendingEnrollment copyWith({
    String? applicationType,
    String? previousSchoolName,
    String? previousSchoolAddress,
  }) {
    return PendingEnrollment(
      enrollmentId: enrollmentId,
      studentId: studentId,
      studentName: studentName,
      lrn: lrn,
      studentNumber: studentNumber,
      sex: sex,
      birthDate: birthDate,
      gradeLevel: gradeLevel,
      schoolLevel: schoolLevel,
      schoolYear: schoolYear,
      section: section,
      applicationType: applicationType ?? this.applicationType,
      previousSchoolName: previousSchoolName ?? this.previousSchoolName,
      previousSchoolAddress:
          previousSchoolAddress ?? this.previousSchoolAddress,
    );
  }

  String get initials {
    final parts = studentName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty);
    final letters = parts.take(2).map((p) => p[0]).join().toUpperCase();
    return letters.isEmpty ? '?' : letters;
  }
}
