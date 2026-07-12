/// A single enrolled student within a section, from
/// `GET /api/enrollments/?section_advisory=<id>`. Per the RBAC handoff,
/// [enrollmentId] (not the student's own id) is the key used for both
/// attendance and score-entry submissions. `student_name` is a top-level
/// field on `EnrollmentSerializer` (server-computed full name) — confirmed
/// against `enrollments/serializers.py`; there is no nested `student` object
/// with a combined `name` field.
class RosterEntry {
  const RosterEntry({required this.enrollmentId, required this.studentName});

  factory RosterEntry.fromJson(Map<String, dynamic> json) {
    return RosterEntry(
      enrollmentId: json['enrollment_id'] as int,
      studentName: json['student_name'] as String? ?? '',
    );
  }

  final int enrollmentId;
  final String studentName;

  String get initials {
    final parts = studentName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}
