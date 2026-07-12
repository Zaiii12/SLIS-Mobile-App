/// A weighted grading component (e.g. "Written Work" 30%) under a
/// [GradingTemplate]. Confirmed against `grading/serializers.py`
/// (`GradingComponentSerializer`): primary key is `grading_component_id`,
/// name field is `component_name` — there is no plain `id`/`name`. Design
/// defaults (Written Work 30%, Performance Task 50%, Quarterly Exam 20%) are
/// NOT hardcoded here — always fetched, per the handoff.
class GradingComponent {
  const GradingComponent({required this.id, required this.name, required this.weight});

  factory GradingComponent.fromJson(Map<String, dynamic> json) {
    return GradingComponent(
      id: json['grading_component_id'] as int,
      name: json['component_name'] as String? ?? '',
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
    );
  }

  final int id;
  final String name;
  final double weight;
}
