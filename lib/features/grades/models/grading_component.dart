/// A weighted grading component (e.g. "Written Work" 30%) under a
/// [GradingTemplate], from `GET /api/grading-components/`. Design defaults
/// (Written Work 30%, Performance Task 50%, Quarterly Exam 20%) are NOT
/// hardcoded here — always fetched, per the handoff.
class GradingComponent {
  const GradingComponent({required this.id, required this.name, required this.weight});

  factory GradingComponent.fromJson(Map<String, dynamic> json) {
    return GradingComponent(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
    );
  }

  final int id;
  final String name;
  final double weight;
}
