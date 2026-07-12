import '../../advisory/models/section_advisory.dart';

/// A school-level-specific grading template, from
/// `GET /api/grading-templates/`. Its [id] is passed to
/// `GET /api/grading-components/?grading_template=<id>` to fetch weighted
/// components for that level.
class GradingTemplate {
  const GradingTemplate({required this.id, required this.schoolLevel});

  factory GradingTemplate.fromJson(Map<String, dynamic> json) {
    return GradingTemplate(
      id: json['id'] as int,
      schoolLevel: json['school_level'] as String? ?? '',
    );
  }

  final int id;
  final String schoolLevel;
}

String schoolLevelToJson(SchoolLevel level) {
  switch (level) {
    case SchoolLevel.elementary:
      return 'elementary';
    case SchoolLevel.juniorHighschool:
      return 'junior_highschool';
    case SchoolLevel.seniorHighschool:
      return 'senior_highschool';
  }
}
