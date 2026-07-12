/// From `GET /api/subjects/`. Field names confirmed against
/// `subjects/serializers.py`: primary key is `subject_id`, display name is
/// `subject_name` (there is no plain `id`/`name`). `gradingTemplateId` comes
/// from the embedded `grading_template` FK id (nullable — a subject with no
/// template assigned has no gradable components).
class Subject {
  const Subject({required this.id, required this.name, required this.gradingTemplateId});

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['subject_id'] as int,
      name: json['subject_name'] as String? ?? '',
      gradingTemplateId: json['grading_template'] as int?,
    );
  }

  final int id;
  final String name;
  final int? gradingTemplateId;
}
