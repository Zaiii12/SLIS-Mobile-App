import '../../advisory/models/section_advisory.dart' show SchoolLevel, schoolLevelFromJson;

/// From `GET /api/subjects/`. Field names confirmed against
/// `subjects/serializers.py`: primary key is `subject_id`, display name is
/// `subject_name` (there is no plain `id`/`name`). `gradingTemplateId` comes
/// from the embedded `grading_template` FK id (nullable — a subject with no
/// template assigned has no gradable components). `gradeLevel`/`strand` are
/// plain strings; `schoolLevel` is parsed into the same [SchoolLevel] enum
/// `SectionAdvisory` uses.
class Subject {
  const Subject({
    required this.id,
    required this.name,
    required this.gradingTemplateId,
    required this.schoolLevel,
    required this.gradeLevel,
    this.strand,
  });

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['subject_id'] as int,
      name: json['subject_name'] as String? ?? '',
      gradingTemplateId: json['grading_template'] as int?,
      schoolLevel: schoolLevelFromJson(json['school_level'] as String? ?? ''),
      gradeLevel: json['grade_level'] as String? ?? '',
      strand: json['strand'] as String?,
    );
  }

  final int id;
  final String name;
  final int? gradingTemplateId;
  final SchoolLevel schoolLevel;
  final String gradeLevel;
  final String? strand;
}
