enum SchoolLevel { elementary, juniorHighschool, seniorHighschool }

SchoolLevel _schoolLevelFromJson(String value) {
  switch (value) {
    case 'elementary':
      return SchoolLevel.elementary;
    case 'senior_highschool':
      return SchoolLevel.seniorHighschool;
    default:
      return SchoolLevel.juniorHighschool;
  }
}

/// A teacher's assigned section, and the scoping mechanism for Attendance
/// and Grades per the RBAC handoff: every subsequent attendance/grades
/// query uses [id] as the section key, and [schoolLevel] drives which
/// grading period options are shown.
class SectionAdvisory {
  const SectionAdvisory({
    required this.id,
    required this.teacherUserId,
    required this.schoolLevel,
    required this.gradeLevel,
    required this.section,
  });

  factory SectionAdvisory.fromJson(Map<String, dynamic> json) {
    return SectionAdvisory(
      id: json['id'] as int,
      teacherUserId: json['teacher_user_id'] as int,
      schoolLevel: _schoolLevelFromJson(json['school_level'] as String? ?? ''),
      gradeLevel: json['grade_level'] as int? ?? 0,
      section: json['section'] as String? ?? '',
    );
  }

  final int id;
  final int teacherUserId;
  final SchoolLevel schoolLevel;
  final int gradeLevel;
  final String section;

  /// Display label, e.g. "Grade 6 - Faith".
  String get displayName => 'Grade $gradeLevel - $section';
}
