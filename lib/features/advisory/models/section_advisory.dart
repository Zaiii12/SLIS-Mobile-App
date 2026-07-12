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

/// A teacher's assigned section, from `GET /api/section-advisories/`. There
/// is no `section_advisory` filter on `/api/enrollments/` or `/api/attendance/`
/// server-side — per `enrollments/models.py`'s `SectionAdvisory` and
/// `accounts/permissions.py`'s `teacher_student_ids()`, an advisory is really
/// just a saved (school_year, school_level, grade_level, section[, strand])
/// tuple, and scoping a section's roster/attendance means filtering by those
/// fields directly, not by [id].
class SectionAdvisory {
  const SectionAdvisory({
    required this.id,
    required this.teacherUserId,
    required this.schoolYear,
    required this.schoolLevel,
    required this.gradeLevel,
    required this.section,
    required this.strand,
  });

  factory SectionAdvisory.fromJson(Map<String, dynamic> json) {
    return SectionAdvisory(
      id: json['advisory_id'] as int,
      teacherUserId: json['teacher_user_id'] as int,
      schoolYear: json['school_year'] as String? ?? '',
      schoolLevel: _schoolLevelFromJson(json['school_level'] as String? ?? ''),
      gradeLevel: json['grade_level'] as String? ?? '',
      section: json['section'] as String? ?? '',
      strand: json['strand'] as String?,
    );
  }

  final int id;
  final int teacherUserId;
  final String schoolYear;
  final SchoolLevel schoolLevel;
  final String gradeLevel;
  final String section;
  final String? strand;

  /// Display label, e.g. "Grade 6 - Faith".
  String get displayName => '$gradeLevel - $section';
}
