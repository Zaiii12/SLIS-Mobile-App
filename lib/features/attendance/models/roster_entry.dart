/// A single enrolled student within a section, from
/// `GET /api/enrollments/?section_advisory=<id>`. Per the RBAC handoff,
/// [enrollmentId] (not the student's own id) is the key used for both
/// attendance and score-entry submissions.
class RosterEntry {
  const RosterEntry({required this.enrollmentId, required this.studentName});

  factory RosterEntry.fromJson(Map<String, dynamic> json) {
    final student = json['student'];
    final name = student is Map<String, dynamic>
        ? student['name'] as String? ?? ''
        : json['student_name'] as String? ?? '';
    return RosterEntry(
      enrollmentId: json['id'] as int,
      studentName: name,
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
