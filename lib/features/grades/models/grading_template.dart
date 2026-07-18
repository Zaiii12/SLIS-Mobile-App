import '../../advisory/models/section_advisory.dart';
import 'grading_component.dart';

/// A grading template with its weighted components embedded. Confirmed
/// against `subjects/serializers.py`'s `grading_template_detail` (the shape
/// returned nested inside a `Subject` response) and
/// `grading/serializers.py`'s `GradingTemplateSerializer` (the shape at
/// `GET /api/grading-templates/<id>/` directly) — both use
/// `grading_template_id` as the pk and nest `components` inline, so there is
/// no separate `/api/grading-components/?grading_template=<id>` fetch needed:
/// a `Subject`'s own `grading_template_detail` already carries everything.
class GradingTemplate {
  const GradingTemplate({required this.id, required this.schoolLevel, required this.components});

  factory GradingTemplate.fromJson(Map<String, dynamic> json) {
    final rawComponents = json['components'] as List? ?? const [];
    return GradingTemplate(
      id: json['grading_template_id'] as int,
      schoolLevel: json['school_level'] as String? ?? '',
      components: rawComponents.cast<Map<String, dynamic>>().map(GradingComponent.fromJson).toList(),
    );
  }

  final int id;
  final String schoolLevel;
  final List<GradingComponent> components;
}

String schoolLevelToJson(SchoolLevel level) {
  switch (level) {
    case SchoolLevel.nursery:
      return 'nursery';
    case SchoolLevel.kindergarten:
      return 'kindergarten';
    case SchoolLevel.elementary:
      return 'elementary';
    case SchoolLevel.juniorHighschool:
      return 'junior_highschool';
    case SchoolLevel.seniorHighschool:
      return 'senior_highschool';
  }
}
