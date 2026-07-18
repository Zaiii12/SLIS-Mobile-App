enum SchoolLevel { nursery, kindergarten, elementary, juniorHighschool, seniorHighschool }

extension SchoolLevelLabel on SchoolLevel {
  /// Human-readable label, e.g. for filter pickers.
  String get label {
    switch (this) {
      case SchoolLevel.nursery:
        return 'Nursery';
      case SchoolLevel.kindergarten:
        return 'Kindergarten';
      case SchoolLevel.elementary:
        return 'Elementary';
      case SchoolLevel.juniorHighschool:
        return 'Junior High School';
      case SchoolLevel.seniorHighschool:
        return 'Senior High School';
    }
  }
}

SchoolLevel _schoolLevelFromJson(String value) {
  switch (value) {
    case 'nursery':
      return SchoolLevel.nursery;
    case 'kindergarten':
      return SchoolLevel.kindergarten;
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

  /// Filters [advisories] down to only those matching the latest
  /// `school_year` present in the list (plain string comparison — school
  /// year strings are zero-padded 4-digit years like "2025-2026", which
  /// sort correctly lexicographically). Advisories carrying an empty
  /// `school_year` are excluded from the comparison but kept if no other
  /// school year is present.
  ///
  /// The API intentionally returns every advisory for a teacher across all
  /// school years (see [AdvisoryApi.fetchSectionAdvisories]) since the web
  /// and mobile apps have historically disagreed on which calendar month a
  /// new school year starts. Picking the max school_year string client-side
  /// avoids depending on any single cutover-month rule.
  static List<SectionAdvisory> forMostRecentSchoolYear(List<SectionAdvisory> advisories) {
    final withYear = advisories.where((a) => a.schoolYear.isNotEmpty);
    if (withYear.isEmpty) return advisories;
    final latest = withYear.map((a) => a.schoolYear).reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
    return advisories.where((a) => a.schoolYear == latest).toList();
  }
}
