/// The five real `enrollment_status` values, per `Enrollment.STATUS_CHOICES`
/// in enrollment-service's `enrollments/models.py`.
const enrollmentStatuses = ['enrolled', 'pending', 'cancelled', 'completed', 'transferred_out'];

String enrollmentStatusLabel(String status) {
  switch (status) {
    case 'enrolled':
      return 'Enrolled';
    case 'pending':
      return 'Pending';
    case 'cancelled':
      return 'Cancelled';
    case 'completed':
      return 'Completed';
    case 'transferred_out':
      return 'Transferred Out';
    default:
      return status;
  }
}

/// A single enrollment record, from `GET/PATCH /api/enrollments/<id>/`.
/// Field names confirmed against `enrollments/serializers.py`'s
/// `EnrollmentSerializer` — `student_detail` nests LRN/student_number/sex/
/// birth_date (`StudentSummarySerializer`). Distinct from the list-oriented
/// [PendingEnrollment]/[RecentEnrollment] models: this one is keyed for a
/// single-record detail+edit view, not a roster row.
///
/// Only [section] and [enrollmentStatus] are safely PATCH-able from mobile
/// without extra fields — per `EnrollmentSerializer.validate()`, changing
/// `grade_level`/`school_level`/`strand`/`semester` on an *existing*
/// enrollment requires `progression_override=true` plus a written
/// `progression_override_reason`, or the server rejects the PATCH outright.
/// That override flow needs the web's eligibility panel, so this mobile
/// model treats those four fields as display-only.
class Enrollment {
  const Enrollment({
    required this.enrollmentId,
    required this.studentId,
    required this.studentName,
    required this.lrn,
    required this.studentNumber,
    required this.sex,
    required this.birthDate,
    required this.schoolYear,
    required this.schoolLevel,
    required this.gradeLevel,
    required this.section,
    required this.strand,
    required this.semester,
    required this.enrollmentStatus,
  });

  factory Enrollment.fromJson(Map<String, dynamic> json) {
    final studentDetail = json['student_detail'] as Map<String, dynamic>?;
    return Enrollment(
      enrollmentId: json['enrollment_id'].toString(),
      studentId: (json['student_id'] ?? json['student']).toString(),
      studentName: json['student_name'] as String? ?? '',
      lrn: studentDetail?['lrn'] as String? ?? '',
      studentNumber: studentDetail?['student_number'] as String?,
      sex: studentDetail?['sex'] as String? ?? '',
      birthDate: studentDetail?['birth_date'] as String? ?? '',
      schoolYear: json['school_year'] as String? ?? '',
      schoolLevel: json['school_level'] as String? ?? '',
      gradeLevel: json['grade_level'] as String? ?? '',
      section: json['section'] as String? ?? '',
      strand: json['strand'] as String?,
      semester: json['semester'] as String?,
      enrollmentStatus: json['enrollment_status'] as String? ?? 'enrolled',
    );
  }

  final String enrollmentId;
  final String studentId;
  final String studentName;
  final String lrn;
  final String? studentNumber;
  final String sex;
  final String birthDate;
  final String schoolYear;
  final String schoolLevel;
  final String gradeLevel;
  final String section;
  final String? strand;
  final String? semester;
  final String enrollmentStatus;

  String get initials {
    final parts = studentName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}
